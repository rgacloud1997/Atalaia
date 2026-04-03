import uuid

import geopandas as gpd
import pandas as pd

INPUT_PATH = r"C:\Users\prber\Downloads\ne_10m_admin_0_countries_lakes\ne_10m_admin_0_countries_lakes.shp"
OUTPUT_CSV = r"C:\Users\prber\Downloads\locations_world_continents_countries.csv"

CONTINENT_CODE = {
    "Africa": "af",
    "Europe": "eu",
    "Asia": "as",
    "North America": "na",
    "South America": "sa",
    "Oceania": "oc",
    "Antarctica": "an",
}


def stable_uuid(name: str) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"atalaia:{name}"))


def bbox_center(geom):
    minx, miny, maxx, maxy = geom.bounds
    center_lng = (minx + maxx) / 2.0
    center_lat = (miny + maxy) / 2.0
    return miny, minx, maxy, maxx, center_lat, center_lng


def main() -> None:
    gdf = gpd.read_file(INPUT_PATH)

    if gdf.crs is None:
        raise ValueError("CRS indefinido no dataset. Converta para EPSG:4326 antes.")
    if gdf.crs.to_epsg() != 4326:
        gdf = gdf.to_crs(4326)

    needed_cols = ["ISO_A2", "ISO_A3", "ADMIN", "CONTINENT", "geometry"]
    missing = [c for c in needed_cols if c not in gdf.columns]
    if missing:
        raise ValueError(
            f"Dataset não tem colunas esperadas: {missing}. "
            f"Colunas encontradas: {list(gdf.columns)}"
        )

    rows: list[dict] = []

    world_id = stable_uuid("world")
    rows.append(
        {
            "id": world_id,
            "level": "world",
            "parent_id": None,
            "code": "world",
            "name": "World",
            "path": "world",
            "center_lat": 0.0,
            "center_lng": 0.0,
            "bbox_min_lat": -90.0,
            "bbox_min_lng": -180.0,
            "bbox_max_lat": 90.0,
            "bbox_max_lng": 180.0,
        }
    )

    continent_ids = {code: stable_uuid(f"continent:{code}") for code in CONTINENT_CODE.values()}

    for cont_name, cont_code in CONTINENT_CODE.items():
        subset = gdf[gdf["CONTINENT"] == cont_name]
        if subset.empty:
            continue

        b = subset.geometry.bounds
        minx = b["minx"].min()
        miny = b["miny"].min()
        maxx = b["maxx"].max()
        maxy = b["maxy"].max()
        center_lng = (minx + maxx) / 2.0
        center_lat = (miny + maxy) / 2.0

        rows.append(
            {
                "id": continent_ids[cont_code],
                "level": "continent",
                "parent_id": world_id,
                "code": cont_code,
                "name": cont_name,
                "path": f"world/{cont_code}",
                "center_lat": center_lat,
                "center_lng": center_lng,
                "bbox_min_lat": miny,
                "bbox_min_lng": minx,
                "bbox_max_lat": maxy,
                "bbox_max_lng": maxx,
            }
        )

    for _, r in gdf.iterrows():
        cont_name = r["CONTINENT"]
        if cont_name not in CONTINENT_CODE:
            continue
        cont_code = CONTINENT_CODE[cont_name]

        iso2 = str(r["ISO_A2"]).strip().lower()
        iso3 = str(r["ISO_A3"]).strip().lower()
        name = str(r["ADMIN"]).strip()

        if not iso2 or iso2 == "-99":
            if not iso3 or iso3 == "-99":
                continue
            iso2 = f"x-{iso3}"

        geom = r["geometry"]
        miny, minx, maxy, maxx, center_lat, center_lng = bbox_center(geom)

        country_id = stable_uuid(f"country:{cont_code}:{iso2}")
        rows.append(
            {
                "id": country_id,
                "level": "country",
                "parent_id": continent_ids[cont_code],
                "code": iso2,
                "name": name,
                "path": f"world/{cont_code}/{iso2}",
                "center_lat": center_lat,
                "center_lng": center_lng,
                "bbox_min_lat": miny,
                "bbox_min_lng": minx,
                "bbox_max_lat": maxy,
                "bbox_max_lng": maxx,
            }
        )

    df = pd.DataFrame(rows)

    if df["path"].isna().any():
        raise ValueError("Há linhas com path nulo.")
    if df["path"].duplicated().any():
        dups = df[df["path"].duplicated(keep=False)].sort_values("path")
        raise ValueError(
            f"Paths duplicados encontrados:\n{dups[['level','code','name','path']].head(30)}"
        )

    df.to_csv(OUTPUT_CSV, index=False, na_rep="")
    print(f"✅ CSV gerado: {OUTPUT_CSV} | linhas: {len(df)}")


if __name__ == "__main__":
    main()
