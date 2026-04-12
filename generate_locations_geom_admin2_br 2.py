#!/usr/bin/env python3
import argparse
import re
import unicodedata
import pandas as pd
import geopandas as gpd
from shapely.geometry import MultiPolygon, Polygon

def slugify(s: str) -> str:
    s = (s or "").strip().lower()
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode("ascii")
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s or "unknown"

def pick_col(cols, *candidates):
    lower = {c.lower(): c for c in cols}
    for cand in candidates:
        if cand.lower() in lower:
            return lower[cand.lower()]
    return None

def to_multipolygon(geom):
    if geom is None:
        return None
    if isinstance(geom, MultiPolygon):
        return geom
    if isinstance(geom, Polygon):
        return MultiPolygon([geom])
    # GeometryCollection etc: tenta extrair polígonos
    try:
        polys = []
        for g in getattr(geom, "geoms", []):
            if isinstance(g, Polygon):
                polys.append(g)
            elif isinstance(g, MultiPolygon):
                polys.extend(list(g.geoms))
        return MultiPolygon(polys) if polys else None
    except Exception:
        return None

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    gdf = gpd.read_file(args.input)
    if gdf.crs is None:
        gdf = gdf.set_crs("EPSG:4326")
    else:
        gdf = gdf.to_crs("EPSG:4326")

    # Colunas comuns no Natural Earth Admin2
    col_admin = pick_col(gdf.columns, "admin", "ADMIN")
    col_adm0  = pick_col(gdf.columns, "adm0_a3", "ADM0_A3", "iso_a3", "ISO_A3")
    col_name  = pick_col(gdf.columns, "name", "NAME", "name_en", "NAME_EN")
    col_iso2  = pick_col(gdf.columns, "iso_3166_2", "ISO_3166_2")
    col_state = pick_col(gdf.columns, "provname", "prov_name", "admin1name", "adm1name", "name_1", "NAME_1")

    if not (col_admin or col_adm0):
        raise SystemExit(f"Não achei colunas para identificar país (admin/adm0_a3). Colunas: {list(gdf.columns)}")
    if not col_name:
        raise SystemExit(f"Não achei coluna de nome (name/name_en). Colunas: {list(gdf.columns)}")

    # Filtra Brasil
    if col_adm0:
        br = gdf[gdf[col_adm0].astype(str).str.upper().eq("BRA")]
    else:
        br = gdf[gdf[col_admin].astype(str).str.lower().eq("brazil")]

    if br.empty:
        raise SystemExit("Filtro do Brasil retornou 0 linhas. Precisamos revisar as colunas do shapefile.")

    rows = []
    for _, r in br.iterrows():
        name = str(r.get(col_name) or "").strip()
        if not name:
            continue

        # UF preferencialmente de ISO_3166_2: "BR-AC" => "ac"
        uf = None
        iso2 = str(r.get(col_iso2) or "").strip()
        if iso2.upper().startswith("BR-") and len(iso2) >= 5:
            uf = iso2.split("-", 1)[1].strip().lower()

        # fallback: tenta inferir por nome do estado (provname)
        if not uf and col_state:
            uf = slugify(str(r.get(col_state) or ""))[:2]  # fallback fraco

        if not uf:
            # sem UF não conseguimos montar path consistente
            continue

        geom = to_multipolygon(r.geometry)
        if geom is None or geom.is_empty:
            continue

        # Centro: use representative_point (garante dentro do polígono -> evita "pin fora")
        rp = geom.representative_point()
        center_lat = float(rp.y)
        center_lng = float(rp.x)

        minx, miny, maxx, maxy = geom.bounds
        bbox_min_lat = float(miny)
        bbox_min_lng = float(minx)
        bbox_max_lat = float(maxy)
        bbox_max_lng = float(maxx)

        city_slug = slugify(name)
        path = f"world/sa/br/{uf}/{city_slug}"
        code = f"br-{uf}-{city_slug}"

        rows.append({
            "path": path,
            "geom_wkt": geom.wkt,
            "bbox_min_lat": bbox_min_lat,
            "bbox_min_lng": bbox_min_lng,
            "bbox_max_lat": bbox_max_lat,
            "bbox_max_lng": bbox_max_lng,
            "center_lat": center_lat,
            "center_lng": center_lng,
            "name": name,
            "code": code,
        })

    df = pd.DataFrame(rows)
    if df.empty:
        raise SystemExit("Gerou 0 linhas (provável falha ao obter UF / ISO_3166_2).")

    df.to_csv(args.out, index=False)
    print(f"OK: wrote {len(df)} rows -> {args.out}")

if __name__ == "__main__":
    main()