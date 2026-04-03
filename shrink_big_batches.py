import os, re
from pathlib import Path

# ===== CONFIG =====
IN_DIR  = r"C:\Users\prber\Downloads\sql_import_geom"         # sua pasta atual (onde estão os 001..023)
OUT_DIR = r"C:\Users\prber\Downloads\sql_import_geom_shrunk"  # saída
MAX_BYTES = 220_000   # se continuar estourando, baixe p/ 160_000
# ==================

INSERT_RE = re.compile(
    r"(?is)^\s*(insert\s+into\s+public\.locations_geom_import\s*\([^)]*\)\s*values)\s*(.*?)(\s*on\s+conflict\s*\(\s*path\s*\).*?)?\s*;\s*$"
)

def split_values(values_blob: str) -> list[str]:
    s = values_blob.strip()
    s = re.sub(r",\s*$", "", s)
    parts = re.split(r"\)\s*,\s*(?=\()", s)
    out = []
    for p in parts:
        p = p.strip()
        if not p.endswith(")"):
            p += ")"
        out.append(p)
    return out

def build_sql(head: str, tuples: list[str], tail: str | None) -> str:
    body = ",\n".join(tuples)
    sql = f"{head}\n{body}\n"
    if tail:
        sql += tail.strip() + "\n"
    sql += ";\n"
    return sql

def write_parts(src: Path, head: str, tuples: list[str], tail: str | None, out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)

    part = 1
    i = 0
    while i < len(tuples):
        # começa com um chunk "grande" e reduz até caber no MAX_BYTES
        lo, hi = 1, min(80, len(tuples) - i)  # 80 é chute inicial
        best = 1

        while lo <= hi:
            mid = (lo + hi) // 2
            sql = build_sql(head, tuples[i:i+mid], tail)
            if len(sql.encode("utf-8")) <= MAX_BYTES:
                best = mid
                lo = mid + 1
            else:
                hi = mid - 1

        sql = build_sql(head, tuples[i:i+best], tail)
        out_path = out_dir / f"{src.stem}_part_{part:03d}.sql"
        out_path.write_text(sql, encoding="utf-8")

        i += best
        part += 1

def main():
    in_dir = Path(IN_DIR)
    out_dir = Path(OUT_DIR)

    files = sorted(in_dir.glob("*.sql"))
    if not files:
        raise SystemExit(f"Nenhum .sql em {IN_DIR}")

    ok = 0
    shrunk = 0

    for f in files:
        txt = f.read_text(encoding="utf-8", errors="ignore").strip()
        m = INSERT_RE.match(txt)

        if not m:
            # copia como está
            (out_dir / f.name).parent.mkdir(parents=True, exist_ok=True)
            (out_dir / f.name).write_text(txt + "\n", encoding="utf-8")
            ok += 1
            continue

        head = m.group(1).strip()
        tuples = split_values(m.group(2))
        tail = (m.group(3) or "").strip() or None

        # se o arquivo já cabe, copia
        if len(txt.encode("utf-8")) <= MAX_BYTES:
            (out_dir / f.name).parent.mkdir(parents=True, exist_ok=True)
            (out_dir / f.name).write_text(txt + "\n", encoding="utf-8")
            ok += 1
        else:
            write_parts(f, head, tuples, tail, out_dir)
            shrunk += 1

    print(f"OK copiados: {ok}")
    print(f"Arquivos quebrados: {shrunk}")
    print(f"Saída: {OUT_DIR}")

if __name__ == "__main__":
    main()