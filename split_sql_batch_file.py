import os
import re
from pathlib import Path

# AJUSTE AQUI
INPUT_SQL = r"C:\Users\prber\Downloads\sql_import_geom\03_import_geom_batch_006.sql"
OUT_DIR   = r"C:\Users\prber\Downloads\sql_import_geom\03_split"
ROWS_PER_FILE = 2  # comece com 2; se ainda estourar, use 1

HEADER_RE = re.compile(r"^\s*insert\s+into\s+public\.locations_geom_import\s*\([^)]+\)\s*values\s*",
                       re.IGNORECASE)

def main():
    inp = Path(INPUT_SQL)
    out = Path(OUT_DIR)
    out.mkdir(parents=True, exist_ok=True)

    text = inp.read_text(encoding="utf-8", errors="ignore").strip()

    # separa header e blocos de VALUES
    m = HEADER_RE.search(text)
    if not m:
        raise SystemExit("Não encontrei o header INSERT ... VALUES no arquivo.")

    header = text[:m.end()].strip()
    values_part = text[m.end():].strip()

    # remove ';' final
    if values_part.endswith(";"):
        values_part = values_part[:-1].strip()

    # separa cada linha "(...)" de values
    # OBS: assumes formato: (..),\n(..),\n(..)
    rows = []
    buf = []
    depth = 0
    started = False
    for ch in values_part:
        if ch == "(":
            depth += 1
            started = True
        if started:
            buf.append(ch)
        if ch == ")":
            depth -= 1
            if started and depth == 0:
                rows.append("".join(buf).strip())
                buf = []
                started = False

    if not rows:
        raise SystemExit("Não consegui extrair as linhas de VALUES.")

    print(f"Linhas encontradas: {len(rows)}")

    # escreve sub-batches
    file_idx = 1
    for i in range(0, len(rows), ROWS_PER_FILE):
        chunk = rows[i:i+ROWS_PER_FILE]
        out_sql = out / f"{inp.stem}_part_{file_idx:03d}.sql"
        body = ",\n".join(chunk)
        out_sql.write_text(f"{header}\n{body}\n;\n", encoding="utf-8")
        file_idx += 1

    print(f"Gerados {file_idx-1} arquivos em: {out}")

if __name__ == "__main__":
    main()