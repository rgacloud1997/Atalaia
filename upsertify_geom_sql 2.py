import os
import re
from pathlib import Path

# ======= CONFIG =======
IN_DIR  = r"C:\Users\prber\Downloads\sql_import_geom"
OUT_DIR = r"C:\Users\prber\Downloads\sql_import_geom_upsert"
# ======================

# Detecta INSERT específico para a tabela de import
INSERT_HEAD_RE = re.compile(
    r"^\s*insert\s+into\s+public\.locations_geom_import\s*"
    r"\(\s*path\s*,\s*geom_wkt\s*,\s*bbox_min_lat\s*,\s*bbox_min_lng\s*,\s*bbox_max_lat\s*,\s*bbox_max_lng\s*\)\s*"
    r"values\s*",
    re.IGNORECASE | re.MULTILINE
)

# Se já tiver ON CONFLICT, não mexe
HAS_ON_CONFLICT_RE = re.compile(r"\bon\s+conflict\s*\(\s*path\s*\)", re.IGNORECASE)

UPSERT_TAIL = """
on conflict (path) do update set
  geom_wkt     = excluded.geom_wkt,
  bbox_min_lat = excluded.bbox_min_lat,
  bbox_min_lng = excluded.bbox_min_lng,
  bbox_max_lat = excluded.bbox_max_lat,
  bbox_max_lng = excluded.bbox_max_lng
;
""".lstrip()

def transform(sql: str) -> str:
    if HAS_ON_CONFLICT_RE.search(sql):
        return sql  # já está em upsert

    m = INSERT_HEAD_RE.search(sql)
    if not m:
        return sql  # não é um insert nosso, deixa como está

    head_end = m.end()
    head = sql[:head_end].rstrip()

    rest = sql[head_end:].strip()

    # remove ';' final (se tiver)
    if rest.endswith(";"):
        rest = rest[:-1].rstrip()

    # Garante que termina em ) (último values)
    # e adiciona upsert tail
    out = f"{head}\n{rest}\n{UPSERT_TAIL}"
    return out

def main():
    in_dir = Path(IN_DIR)
    out_dir = Path(OUT_DIR)
    out_dir.mkdir(parents=True, exist_ok=True)

    files = sorted(in_dir.glob("*.sql"))
    if not files:
        raise SystemExit(f"Nenhum .sql encontrado em: {in_dir}")

    changed = 0
    total = 0

    for f in files:
        total += 1
        txt = f.read_text(encoding="utf-8", errors="ignore")
        new_txt = transform(txt)

        out_path = out_dir / f.name
        out_path.write_text(new_txt, encoding="utf-8")

        if new_txt != txt:
            changed += 1

    print(f"OK. Arquivos lidos: {total}")
    print(f"Convertidos para UPSERT: {changed}")
    print(f"Saída em: {out_dir}")

if __name__ == "__main__":
    main()