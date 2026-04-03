from __future__ import annotations

import os
import re
import sys
from pathlib import Path

# ======= CONFIG PADRÃO (você pode sobrescrever por args) =======
IN_DIR = r"C:\Users\prber\Downloads\sql_import_geom_upsert"
OUT_DIR = r"C:\Users\prber\Downloads\sql_import_geom_resplit"
REF_BATCH = "013"          # se não achar esse batch, cai no modo AUTO (menor arquivo)
MAX_BYTES = 300_000        # limite de tamanho por arquivo (proteção)
ENC = "utf-8"
# =============================================================

INSERT_RE = re.compile(
    r"(?is)^\s*(insert\s+into\s+public\.locations_geom_import\s*\([^)]*\)\s*values)\s*(.*?)(\s*on\s+conflict\s*\(\s*path\s*\).*?)?\s*;\s*$"
)

def split_values(values_blob: str) -> list[str]:
    """
    Extrai cada tupla "(...)" da lista de VALUES, respeitando aspas simples (SQL) e
    parênteses dentro do WKT/strings.
    """
    s = values_blob.strip()
    s = re.sub(r",\s*$", "", s)

    tuples: list[str] = []
    buf: list[str] = []
    depth = 0
    in_string = False
    started = False

    i = 0
    while i < len(s):
        ch = s[i]

        if in_string:
            buf.append(ch)
            if ch == "'":
                if i + 1 < len(s) and s[i + 1] == "'":
                    buf.append("'")
                    i += 1
                else:
                    in_string = False
            i += 1
            continue

        if ch == "'":
            if started:
                buf.append(ch)
            in_string = True
            i += 1
            continue

        if ch == "(":
            depth += 1
            started = True
            buf.append(ch)
            i += 1
            continue

        if started:
            buf.append(ch)
            if ch == ")":
                depth -= 1
                if depth == 0:
                    tuples.append("".join(buf).strip())
                    buf = []
                    started = False
            i += 1
            continue

        i += 1

    return tuples

def build_statement(head: str, body_tuples: list[str], tail: str | None) -> str:
    body = ",\n".join(body_tuples)
    sql = f"{head}\n{body}\n"
    if tail:
        sql += tail.strip() + "\n"
    sql += ";\n"
    return sql

def find_ref_tuple_count(files: list[Path], ref_batch: str) -> int:
    ref = None
    for f in files:
        name = f.name.lower()
        if re.search(rf"(^|_){re.escape(ref_batch.lower())}($|_)", name):
            ref = f
            break
        if name.startswith(ref_batch.lower() + "_") or name.startswith(ref_batch.lower()):
            ref = f
            break
    if ref is None:
        raise FileNotFoundError(f"Não achei o batch de referência {ref_batch} dentro de {files[0].parent if files else 'IN_DIR'}")

    txt = ref.read_text(encoding=ENC, errors="ignore").strip()
    m = INSERT_RE.match(txt)
    if not m:
        raise ValueError(f"O arquivo {ref.name} não bate com o formato INSERT esperado.")
    tuples = split_values(m.group(2))
    return len(tuples)

def find_auto_ref_tuple_count(files: list[Path]) -> tuple[int, Path]:
    candidates: list[tuple[int, Path]] = []
    for f in files:
        txt = f.read_text(encoding=ENC, errors="ignore").strip()
        m = INSERT_RE.match(txt)
        if not m:
            continue
        tuples = split_values(m.group(2))
        if not tuples:
            continue
        candidates.append((len(tuples), f))

    if not candidates:
        raise SystemExit("Não encontrei nenhum arquivo com INSERT INTO public.locations_geom_import (...) VALUES (...) para usar como referência.")

    candidates.sort(key=lambda x: x[0])
    return candidates[0]

def emit_parts(src_file: Path, head: str, tuples: list[str], tail: str | None, max_tuples: int, out_dir: Path, max_bytes: int) -> list[Path]:
    out_files = []
    part_idx = 1
    i = 0
    while i < len(tuples):
        chunk = tuples[i:i+max_tuples]
        sql = build_statement(head, chunk, tail)

        # Se passar do limite por bytes, reduz chunk até caber
        if len(sql.encode(ENC)) > max_bytes and len(chunk) > 1:
            hi = len(chunk)
            lo = 1
            best = None
            while lo <= hi:
                mid = (lo + hi) // 2
                test_sql = build_statement(head, chunk[:mid], tail)
                if len(test_sql.encode(ENC)) <= max_bytes:
                    best = mid
                    lo = mid + 1
                else:
                    hi = mid - 1
            if best is None:
                best = 1
            chunk = chunk[:best]
            sql = build_statement(head, chunk, tail)

        out_path = out_dir / f"{src_file.stem}_part_{part_idx:03d}{src_file.suffix}"
        out_path.write_text(sql, encoding=ENC)
        out_files.append(out_path)

        i += len(chunk)
        part_idx += 1

    return out_files

def main():
    global IN_DIR, OUT_DIR, REF_BATCH, MAX_BYTES

    # Args opcionais:
    # python resplit_geom_sql_folder.py "<in_dir>" "<out_dir>" "<ref_batch>" <max_bytes>
    if len(sys.argv) >= 2:
        IN_DIR = sys.argv[1]
    if len(sys.argv) >= 3:
        OUT_DIR = sys.argv[2]
    if len(sys.argv) >= 4:
        REF_BATCH = sys.argv[3]
    if len(sys.argv) >= 5:
        MAX_BYTES = int(sys.argv[4])

    in_dir = Path(IN_DIR)
    out_dir = Path(OUT_DIR)
    out_dir.mkdir(parents=True, exist_ok=True)

    files = sorted(in_dir.glob("*.sql"))
    if not files:
        raise SystemExit(f"Nenhum .sql encontrado em: {in_dir}")

    ref_count: int
    if REF_BATCH.strip().lower() == "auto":
        ref_count, ref_file = find_auto_ref_tuple_count(files)
        print(f"✅ Referência AUTO: {ref_count} tuplas (menor) em {ref_file.name}")
    else:
        try:
            ref_count = find_ref_tuple_count(files, REF_BATCH)
            print(f"✅ Batch referência {REF_BATCH}: {ref_count} tuplas por arquivo")
        except (FileNotFoundError, ValueError):
            ref_count, ref_file = find_auto_ref_tuple_count(files)
            print(f"⚠️ Não achei/validei o batch {REF_BATCH}; usando AUTO: {ref_count} tuplas (menor) em {ref_file.name}")

    print(f"✅ MAX_BYTES: {MAX_BYTES}")
    print(f"📥 IN:  {in_dir}")
    print(f"📤 OUT: {out_dir}")

    total_in = 0
    total_out = 0

    for f in files:
        total_in += 1
        txt = f.read_text(encoding=ENC, errors="ignore").strip()
        m = INSERT_RE.match(txt)

        # Se não for o formato esperado, copia sem mexer
        if not m:
            out_path = out_dir / f.name
            out_path.write_text(txt + "\n", encoding=ENC)
            total_out += 1
            continue

        head = m.group(1).strip()
        values_blob = m.group(2).strip()
        tail = (m.group(3) or "").strip() or None

        tuples = split_values(values_blob)
        out_files = emit_parts(f, head, tuples, tail, ref_count, out_dir, MAX_BYTES)
        total_out += len(out_files)

    print(f"OK. Arquivos lidos: {total_in}")
    print(f"Arquivos gerados: {total_out}")
    print(f"Saída em: {out_dir}")

if __name__ == "__main__":
    main()
