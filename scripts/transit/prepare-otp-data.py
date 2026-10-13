"""Prepare existing GTFS/OSM inputs for OTP without inventing timetables.

Route selection is optional and retains complete published trips and shapes.
Street cropping needs pyosmium; no routing API or provider account is used.
"""
import argparse
import csv
import hashlib
import io
import json
import os
import shutil
import tempfile
import zipfile
from pathlib import Path


def rows(archive, name):
    return csv.DictReader(io.TextIOWrapper(archive.open(name), encoding="utf-8-sig", newline=""))


def write_csv(archive, name, records, fields):
    with archive.open(name, "w") as binary:
        with io.TextIOWrapper(binary, encoding="utf-8", newline="") as text:
            writer = csv.DictWriter(text, fieldnames=fields, lineterminator="\n")
            writer.writeheader()
            writer.writerows(records)


def select_gtfs(source_path, target_path, route_ids):
    if not route_ids:
        shutil.copyfile(source_path, target_path)
        return
    with zipfile.ZipFile(source_path) as source, zipfile.ZipFile(target_path, "w", zipfile.ZIP_DEFLATED) as target:
        available = {row["route_id"] for row in rows(source, "routes.txt")}
        if missing := route_ids - available:
            raise ValueError(f"Unknown route IDs: {sorted(missing)}")
        trips = [row for row in rows(source, "trips.txt") if row["route_id"] in route_ids]
        if not trips:
            raise ValueError("Selected routes have no scheduled trips")
        trip_ids = {row["trip_id"] for row in trips}
        shape_ids = {row.get("shape_id") for row in trips}
        stop_ids = set()
        reader = rows(source, "stop_times.txt")

        def stop_times():
            for row in reader:
                if row["trip_id"] in trip_ids:
                    stop_ids.add(row["stop_id"])
                    yield row

        write_csv(target, "stop_times.txt", stop_times(), reader.fieldnames)
        stops = list(rows(source, "stops.txt"))
        # Parent stations can themselves refer to a parent; include the full chain.
        while True:
            parents = {row.get("parent_station") for row in stops if row["stop_id"] in stop_ids} - {None, ""}
            if parents <= stop_ids:
                break
            stop_ids.update(parents)
        references = {"trips": trip_ids, "stop_times": trip_ids, "routes": route_ids, "stops": stop_ids}
        for name in source.namelist():
            if name == "stop_times.txt":
                continue
            if name not in {"trips.txt", "routes.txt", "stops.txt", "shapes.txt", "transfers.txt", "translations.txt"}:
                target.writestr(name, source.read(name))  # Retain calendars, fares, feed metadata and attribution.
                continue
            reader = rows(source, name)
            if name == "trips.txt":
                records = trips
            elif name == "routes.txt":
                records = (row for row in reader if row["route_id"] in route_ids)
            elif name == "stops.txt":
                records = (row for row in reader if row["stop_id"] in stop_ids)
            elif name == "shapes.txt":
                records = (row for row in reader if row["shape_id"] in shape_ids)
            elif name == "transfers.txt":
                limits = {"from_stop_id": stop_ids, "to_stop_id": stop_ids, "from_trip_id": trip_ids,
                          "to_trip_id": trip_ids, "from_route_id": route_ids, "to_route_id": route_ids}
                records = (row for row in reader if all(not row.get(key) or row[key] in values for key, values in limits.items()))
            else:
                records = (row for row in reader if row["table_name"] not in references
                           or not row.get("record_id") or row["record_id"] in references[row["table_name"]])
            write_csv(target, name, records, reader.fieldnames)


def crop_streets(source_path, target_path, bounds):
    if bounds is None:
        shutil.copyfile(source_path, target_path)
        return
    import osmium
    west, south, east, north = bounds

    class FindWays(osmium.SimpleHandler):
        def __init__(self):
            super().__init__()
            self.ways, self.nodes = set(), set()

        def way(self, way):
            if "highway" not in way.tags and "railway" not in way.tags:
                return
            if any(node.location.valid() and west <= node.lon <= east and south <= node.lat <= north for node in way.nodes):
                self.ways.add(way.id)
                self.nodes.update(node.ref for node in way.nodes)

    selected = FindWays()
    selected.apply_file(str(source_path), locations=True, idx="sparse_file_array")
    with osmium.SimpleWriter(str(target_path)) as writer:
        class CopyObjects(osmium.SimpleHandler):
            def node(self, node):
                if node.id in selected.nodes:
                    writer.add_node(node)

            def way(self, way):
                if way.id in selected.ways:
                    writer.add_way(way)

            def relation(self, relation):
                if relation.members and all((member.type == "w" and member.ref in selected.ways)
                                           or (member.type == "n" and member.ref in selected.nodes) for member in relation.members):
                    writer.add_relation(relation)

        CopyObjects().apply_file(str(source_path))


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gtfs", type=Path, required=True)
    parser.add_argument("--osm", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--routes", help="Optional comma-separated complete GTFS route IDs")
    parser.add_argument("--bounds", type=float, nargs=4, metavar=("WEST", "SOUTH", "EAST", "NORTH"))
    args = parser.parse_args()
    source_gtfs, source_osm, output = args.gtfs.resolve(strict=True), args.osm.resolve(strict=True), args.output.resolve()
    if source_gtfs.parent == output or source_osm.parent == output:
        parser.error("Keep original inputs outside the output directory")
    if args.bounds and not (-180 <= args.bounds[0] < args.bounds[2] <= 180 and -90 <= args.bounds[1] < args.bounds[3] <= 90):
        parser.error("Invalid street bounds")
    output.mkdir(parents=True, exist_ok=True)
    route_ids = set(args.routes.split(",")) if args.routes else set()
    with tempfile.TemporaryDirectory(prefix="navio-prepare-", dir=output) as temporary:
        stage = Path(temporary).resolve()
        if stage.parent != output:
            raise ValueError("Staging directory escaped the output directory")
        gtfs, osm = stage / "transit.gtfs.zip", stage / "streets.osm.pbf"
        select_gtfs(source_gtfs, gtfs, route_ids)
        crop_streets(source_osm, osm, args.bounds)
        manifest = {"gtfsSha256": digest(source_gtfs), "osmSha256": digest(source_osm),
                    "selectedRoutes": sorted(route_ids), "streetBounds": args.bounds,
                    "notice": "Original timetables and dates preserved. Route/street selection limits coverage."}
        for artifact in (gtfs, osm):
            os.replace(artifact, output / artifact.name)
        (output / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Prepared inputs in {output}. Build a new OTP graph before serving these inputs.")


if __name__ == "__main__":
    main()
