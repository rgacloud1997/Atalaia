from pathlib import Path
import re

# ======= CONFIG =======
IN_DIR  = r"C:\Users\prber\Downloads\sql_import_geom_upsert"   # pasta onde estão 001..023
OUT_DIR = r"C:\Users\prber\Downloads\sql_import_geom_split"    # pasta de saída
REF_BATCH = "013"  # usa esse batch como referência
MAX_BYTES = 350_000  # proteção extra: não deixa nenhum arquivo passar disso
# ======================

INSERT_RE = re.compile(
    r"(?is)^\s*(insert\s+into\s+public\.locations_geom_import\s*\([^)]*\)\s*values)\s*(.*?)(\s*on\s+conflict\s*\(\s*path\s*\).*?)?\s*;\s*$"
)

def split_values(values_blob: str) -> list[str]:
    s = values_blob.strip()
    s = re.sub(r",\s*$", "", s)
    parts = re.split(r"\)\s*,\s*(?=\()", s)
    tuples = []
    for p in parts:
        p = p.strip()
        if not p.endswith(")"):
            p += ")"
        tuples.append(p)
    return tuples

def statement(head: str, body_tuples: list[str], tail: str | None) -> str:
    body = ",\n".join(body_tuples)
    sql = f"{head}\n{body}\n"
    if tail:
        sql += tail.strip() + "\n"
    sql += ";\n"
    return sql

def get_ref_tuple_count(files: list[Path]) -> int:
    # acha o arquivo que contém "_013" ou começa com "013"
    ref = None
    for f in files:
        name = f.name.lower()
        if re.search(rf"(^|_){REF_BATCH}($|_)", name):
            ref = f
            break
        if name.startswith(REF_BATCH + "_") or name.startswith(REF_BATCH):
            ref = f
            break
    if ref is None:
        raise SystemExit(f"Não achei o batch de referência {REF_BATCH} dentro de {IN_DIR}")

    txt = ref.read_text(encoding="utf-8", errors="ignore").strip()
    m = INSERT_RE.match(txt)
    if not m:
        raise SystemExit(f"O arquivo {ref.name} não bate com o formato INSERT esperado.")

    tuples = split_values(m.group(2))
    return len(tuples)

def emit_parts(f: Path, head: str, tuples: list[str], tail: str | None, max_tuples: int, out_dir: Path):
    out_files = []
    part_idx = 1
    i = 0

    while i < len(tuples):
        chunk = tuples[i:i+max_tuples]
        sql = statement(head, chunk, tail)

        # proteção extra: se passar do limite, reduz o chunk até caber
        if len(sql.encode("utf-8")) > MAX_BYTES and len(chunk) > 1:
            # vai reduzindo pela metade até caber
            hi = len(chunk)
            lo = 1
            best = None
            while lo <= hi:
                mid = (lo + hi) // 2
                test_sql = statement(head, chunk[:mid], tail)
                if len(test_sql.encode("utf-8")) <= MAX_BYTES:
                    best = mid
                    lo = mid + 1
                else:
                    hi = mid - 1
            if best is None:
                # até 1 tupla passou: salva mesmo assim e deixa você rodar via psql depois
                best = 1
            chunk = chunk[:best]
            sql = statement(head, chunk, tail)

        out_path = out_dir / f"{f.stem}_part_{part_idx:03d}{f.suffix}"
        out_path.write_text(sql, encoding="utf-8")
        out_files.append(out_path)

        i += len(chunk)
        part_idx += 1

    return out_files

def main():
    in_dir = Path(IN_DIR)
    out_dir = Path(OUT_DIR)
    out_dir.mkdir(parents=True, exist_ok=True)

    files = sorted(in_dir.glob("*.sql"))
    if not files:
        raise SystemExit(f"Nenhum .sql encontrado em: {in_dir}")

    ref_count = get_ref_tuple_count(files)
    print(f"✅ Batch referência {REF_BATCH}: {ref_count} tuplas por arquivo (tamanho padrão)")

    total_in = 0
    total_out = 0

    for f in files:
        txt = f.read_text(encoding="utf-8", errors="ignore").strip()
        total_in += 1

        m = INSERT_RE.match(txt)
        if not m:
            # copia sem mexer
            out_path = out_dir / f.name
            out_path.write_text(txt + "\n", encoding="utf-8")
            total_out += 1
            continue

        head = m.group(1).strip()
        values_blob = m.group(2).strip()
        tail = (m.group(3) or "").strip() or None
        tuples = split_values(values_blob)

        # Sempre re-split padronizado (mesmo se pequeno), pra ficar consistente
        out_files = emit_parts(f, head, tuples, tail, ref_count, out_dir)
        total_out += len(out_files)

    print(f"OK. Arquivos lidos: {total_in}")
    print(f"Arquivos gerados: {total_out}")
    print(f"Saída em: {out_dir}")
    print(f"Proteção MAX_BYTES: {MAX_BYTES}")

if __name__ == "__main__":
    main()