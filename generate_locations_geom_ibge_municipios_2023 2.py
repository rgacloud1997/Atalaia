from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

import geopandas as gpd
import pandas as pd
from shapely.geometry import MultiPolygon, Polygon

UF_SIGLA_BY_CDUF = {
    11: "RO",
    12: "AC",
    13: "AM",
    14: "RR",
    15: "PA",
    16: "AP",
    17: "TO",
    21: "MA",
    22: "PI",
    23: "CE",
    24: "RN",
    25: "PB",
    26: "PE",
    27: "AL",
    28: "SE",
    29: "BA",
    31: "MG",
    32: "ES",
    33: "RJ",
    35: "SP",
    41: "PR",
    42: "SC",
    43: "RS",
    50: "MS",
    51: "MT",
    52: "GO",
    53: "DF",
}


def _to_multipolygon(geom):
    if geom is None:
        return None
    if geom.geom_type == "MultiPolygon":
        return geom
    if geom.geom_type == "Polygon":
        return MultiPolygon([geom])
    try:
        fixed = geom.buffer(0)
        if fixed.geom_type == "Polygon":
            return MultiPolygon([fixed])
        if fixed.geom_type == "MultiPolygon":
            return fixed
    except Exception:
        pass
    return None


def _pick_col(df: pd.DataFrame, candidates: list[str]) -> str | None:
    cols_lower = {c.lower(): c for c in df.columns}
    for cand in candidates:
        c = cols_lower.get(cand.lower())
        if c is not None:
            return c
    return None


def _norm_uf(s: str) -> str | None:
    v = (s or "").strip().lower()
    if re.match(r"^[a-z]{2}$", v):
        return v
    return None


def _uf_sigla_from_row(row, uf_col: str) -> str | None:
    v = row[uf_col]
    if v is None:
        return None

    if isinstance(v, str):
        vv = v.strip()
        if re.match(r"^[A-Za-z]{2}$", vv):
            return vv.upper()
        if re.match(r"^\d{2}$", vv):
            try:
                return UF_SIGLA_BY_CDUF.get(int(vv))
            except Exception:
                return None

    try:
        cd = int(v)
        return UF_SIGLA_BY_CDUF.get(cd)
    except Exception:
        return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help="Path to IBGE municipalities shapefile (.shp)")
    ap.add_argument("--out", required=True, help="Output CSV path")
    ap.add_argument("--min-rows", type=int, default=5000, help="Fail if output has fewer than this rows")
    args = ap.parse_args()

    input_path = Path(args.input)
    out_path = Path(args.out)

    if not input_path.exists():
        raise SystemExit(f"INPUT not found: {input_path}")

    gdf = gpd.read_file(str(input_path))
    if gdf.empty:
        raise SystemExit(f"No features found in: {input_path}")

    if gdf.crs is not None:
        try:
            if str(gdf.crs).upper() != "EPSG:4326":
                gdf = gdf.to_crs(epsg=4326)
        except Exception:
            pass

    col_name = _pick_col(gdf, ["nm_mun", "nome", "name", "nm_municip"])
    col_code = _pick_col(gdf, ["cd_mun", "codmun", "geocodigo", "cd_geocmu", "id"])

    col_uf = None
    for c in gdf.columns:
        if str(c).upper() in ("SIGLA_UF", "UF", "SG_UF"):
            col_uf = c
            break
    if col_uf is None and "CD_UF" in gdf.columns:
        col_uf = "CD_UF"

    if col_name is None or col_code is None or col_uf is None:
        raise SystemExit(
            "Could not find required columns.\n"
            f"Columns found: {list(gdf.columns)}\n"
            f"Picked: name={col_name} code={col_code} uf={col_uf}"
        )

    rows: list[dict] = []
    for _, r in gdf.iterrows():
        uf_sigla = _uf_sigla_from_row(r, col_uf)
        if not uf_sigla:
            continue
        uf = uf_sigla.lower()

        code_str = str(int(r[col_code])).zfill(7) if pd.notna(r[col_code]) else None
        if not code_str:
            continue

        if not uf:
            continue

        geom = _to_multipolygon(r.geometry)
        if geom is None:
            continue

        minx, miny, maxx, maxy = geom.bounds
        p = geom.representative_point()

        mun_name = str(r[col_name]).strip()
        city_code = f"br-{code_str}"
        path = f"world/sa/br/{uf}/{code_str}"

        rows.append(
            {
                "path": path,
                "geom_wkt": geom.wkt,
                "bbox_min_lat": float(miny),
                "bbox_min_lng": float(minx),
                "bbox_max_lat": float(maxy),
                "bbox_max_lng": float(maxx),
                "center_lat": float(p.y),
                "center_lng": float(p.x),
                "name": mun_name,
                "code": city_code,
            }
        )

    if len(rows) < args.min_rows:
        raise SystemExit(
            f"Generated too few rows ({len(rows)}). "
            "Check if the input file is IBGE municipalities and columns mapping is correct."
        )

    df = pd.DataFrame(rows).drop_duplicates(subset=["path"], keep="first").sort_values("path", ascending=True, kind="stable")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(out_path, index=False, encoding="utf-8", quoting=csv.QUOTE_MINIMAL)

    print(f"OK: wrote {len(df)} rows -> {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
