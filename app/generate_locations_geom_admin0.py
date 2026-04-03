import geopandas as gpd
import pandas as pd
from shapely.geometry import MultiPolygon, Polygon

INPUT_PATH = r"C:\Users\prber\Downloads\ne_10m_admin_0_countries_lakes\ne_10m_admin_0_countries_lakes.shp"
OUTPUT_CSV = r"C:\Users\prber\Downloads\locations_geom_import.csv"

CONT_MAP = {
    "Africa": "af",
    "Europe": "eu",
    "Asia": "as",
    "North America": "na",
    "South America": "sa",
    "Oceania": "oc",
    "Antarctica": "an",
}


def to_multipolygon(geom):
    if geom is None:
        return None
    if getattr(geom, "is_empty", False):
        return None
    if isinstance(geom, MultiPolygon):
        return geom
    if isinstance(geom, Polygon):
        return MultiPolygon([geom])
    if not hasattr(geom, "geoms"):
        return None
    polys: list[Polygon] = []
    for g in geom.geoms:
        if isinstance(g, Polygon):
            polys.append(g)
        elif isinstance(g, MultiPolygon):
            polys.extend(list(g.geoms))
    if not polys:
        return None
    return MultiPolygon(polys)


def main() -> None:
    gdf = gpd.read_file(INPUT_PATH)
    if gdf.crs is None:
        raise ValueError("CRS indefinido no dataset. Converta para EPSG:4326 antes.")
    if gdf.crs.to_epsg() != 4326:
        gdf = gdf.to_crs(4326)

    needed_cols = ["ISO_A2", "ISO_A3", "CONTINENT", "geometry"]
    missing = [c for c in needed_cols if c not in gdf.columns]
    if missing:
        raise ValueError(f"Dataset não tem colunas esperadas: {missing}. Colunas encontradas: {list(gdf.columns)}")

    rows: list[dict] = []
    for _, r in gdf.iterrows():
        cont_name = str(r.get("CONTINENT", "")).strip()
        cont_code = CONT_MAP.get(cont_name)
        if not cont_code:
            continue

        iso2 = str(r.get("ISO_A2", "")).strip().lower()
        iso3 = str(r.get("ISO_A3", "")).strip().upper()
        if not iso2 or iso2 == "-99":
            if not iso3 or iso3 == "-99":
                continue
            iso2 = f"x-{iso3.lower()}"

        path = f"world/{cont_code}/{iso2}"

        geom = to_multipolygon(r.geometry)
        if geom is None:
            continue

        minx, miny, maxx, maxy = geom.bounds
        rows.append(
            {
                "path": path,
                "geom_wkt": geom.wkt,
                "bbox_min_lat": float(miny),
                "bbox_min_lng": float(minx),
                "bbox_max_lat": float(maxy),
                "bbox_max_lng": float(maxx),
            }
        )

    df = pd.DataFrame(rows).drop_duplicates(subset=["path"]).sort_values("path")
    if df["path"].isna().any():
        raise ValueError("Há linhas com path nulo.")
    df.to_csv(OUTPUT_CSV, index=False, na_rep="")
    print(f"✅ CSV gerado: {OUTPUT_CSV} | linhas: {len(df)}")


if __name__ == "__main__":
    main()

