from __future__ import annotations

import argparse
import csv
import os
import re
import sys
from pathlib import Path

import geopandas as gpd
import pandas as pd
from shapely.geometry import MultiPolygon, Polygon


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


_UF_BY_NAME = {
    "acre": "ac",
    "alagoas": "al",
    "amapá": "ap",
    "amazonas": "am",
    "bahia": "ba",
    "ceará": "ce",
    "distrito federal": "df",
    "espírito santo": "es",
    "goiás": "go",
    "maranhão": "ma",
    "mato grosso": "mt",
    "mato grosso do sul": "ms",
    "minas gerais": "mg",
    "pará": "pa",
    "paraíba": "pb",
    "paraná": "pr",
    "pernambuco": "pe",
    "piauí": "pi",
    "rio de janeiro": "rj",
    "rio grande do norte": "rn",
    "rio grande do sul": "rs",
    "rondônia": "ro",
    "roraima": "rr",
    "santa catarina": "sc",
    "são paulo": "sp",
    "sergipe": "se",
    "tocantins": "to",
}


def _extract_state_code(row, col_code: str | None, col_iso2: str | None, col_name: str) -> str | None:
    if col_code is not None and pd.notna(row[col_code]):
        v = str(row[col_code]).strip()
        if re.match(r"^[A-Za-z]{2}$", v):
            return v.lower()

    if col_iso2 is not None and pd.notna(row[col_iso2]):
        v = str(row[col_iso2]).strip()
        m = re.match(r"^BR-([A-Z]{2})$", v)
        if m:
            return m.group(1).lower()

    name = str(row[col_name]).strip().lower()
    return _UF_BY_NAME.get(name)


def _is_brazil_row(row, col_admin: str) -> bool:
    v = str(row[col_admin]).strip().upper()
    if v in {"BRAZIL", "BR", "BRA"}:
        return True
    return "BRAZIL" in v


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help="Path to BR states shapefile/geojson")
    ap.add_argument("--out", required=True, help="Output CSV path")
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
            if str(gdf.crs).upper() not in {"EPSG:4326", "WGS84"}:
                gdf = gdf.to_crs(epsg=4326)
        except Exception:
            pass

    col_admin = _pick_col(gdf, ["admin", "adm0_a3", "iso_a2", "iso_a3", "country", "pais", "país"])
    if col_admin is not None:
        mask = gdf.apply(lambda r: _is_brazil_row(r, col_admin), axis=1)
        if int(mask.sum()) >= 10:
            gdf = gdf[mask].copy()

    col_name = _pick_col(gdf, ["name", "nome", "nm_uf", "nm_estado", "state_name"])
    col_code = _pick_col(gdf, ["sigla", "sg_uf", "uf", "abbr"])
    col_iso2 = _pick_col(gdf, ["iso_3166_2", "iso2"])

    if col_name is None:
        raise SystemExit(f"Could not find a name column. Available columns: {list(gdf.columns)}")

    rows: list[dict] = []
    for _, r in gdf.iterrows():
        geom = _to_multipolygon(r.geometry)
        if geom is None:
            continue

        name = str(r[col_name]).strip()
        code = _extract_state_code(r, col_code, col_iso2, col_name)
        if not code:
            continue

        geom_4326 = geom
        minx, miny, maxx, maxy = geom_4326.bounds
        p = geom_4326.representative_point()

        rows.append(
            {
                "path": f"world/sa/br/{code}",
                "geom_wkt": geom_4326.wkt,
                "bbox_min_lat": float(miny),
                "bbox_min_lng": float(minx),
                "bbox_max_lat": float(maxy),
                "bbox_max_lng": float(maxx),
                "center_lat": float(p.y),
                "center_lng": float(p.x),
                "name": name,
                "code": code,
            }
        )

    if not rows:
        raise SystemExit("No state rows extracted. Check your input file/columns.")

    df = pd.DataFrame(rows).drop_duplicates(subset=["path"], keep="first")
    df = df.sort_values("path", ascending=True, kind="stable")

    missing = sorted(set(_UF_BY_NAME.values()) - set(df["code"].tolist()))
    if missing:
        print(f"WARNING: missing UF codes: {', '.join(missing)}", file=sys.stderr)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(
        out_path,
        index=False,
        encoding="utf-8",
        quoting=csv.QUOTE_MINIMAL,
    )

    print(f"OK: wrote {len(df)} rows -> {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
