import csv
import os
from math import ceil
import sys

csv.field_size_limit(1024 * 1024 * 200)  # 200 MB

CSV_PATH = r"C:\Users\prber\Downloads\locations_geom_import.csv"  # <- vamos ajustar
OUT_DIR = r"C:\Users\prber\Downloads\sql_import_geom"
BATCH_SIZE = 10

TABLE = "public.locations_geom_import"
COLS = ["path", "geom_wkt", "bbox_min_lat", "bbox_min_lng", "bbox_max_lat", "bbox_max_lng"]

def sql_escape(s: str) -> str:
    return s.replace("'", "''")

def row_to_values(r: dict) -> str:
    path = sql_escape(r["path"])
    wkt = sql_escape(r["geom_wkt"])
    return f"('{path}', '{wkt}', {r['bbox_min_lat']}, {r['bbox_min_lng']}, {r['bbox_max_lat']}, {r['bbox_max_lng']})"

def write_insert(filename: str, rows: list[dict]):
    cols_sql = ", ".join(COLS)
    values_sql = ",\n".join(row_to_values(r) for r in rows)
    sql = f"""insert into {TABLE} ({cols_sql})
values
{values_sql}
;
"""
    with open(filename, "w", encoding="utf-8") as f:
        f.write(sql)

def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    if not os.path.exists(CSV_PATH):
        raise FileNotFoundError(f"CSV não encontrado: {CSV_PATH}")

    with open(CSV_PATH, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        data = list(reader)

    total = len(data)
    print("Linhas no CSV:", total)

    mid = total // 2
    write_insert(os.path.join(OUT_DIR, "03_import_geom_part_1.sql"), data[:mid])
    write_insert(os.path.join(OUT_DIR, "03_import_geom_part_2.sql"), data[mid:])

    batches = ceil(total / BATCH_SIZE)
    for i in range(batches):
        chunk = data[i*BATCH_SIZE:(i+1)*BATCH_SIZE]
        write_insert(os.path.join(OUT_DIR, f"03_import_geom_batch_{i+1:03d}.sql"), chunk)

    print("Gerado em:", OUT_DIR)
    print("Batches:", batches)

if __name__ == "__main__":
    main()
