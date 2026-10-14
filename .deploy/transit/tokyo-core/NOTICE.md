# Tokyo core transit inputs

Inputs for the production `transit-router` image (`.deploy/docker/transit-router.Dockerfile`).
Prepared with `scripts/transit/prepare-otp-data.py`; `source-manifest.json` records the source
hashes, the six selected rail routes and the street crop bounds.

- `tokyo-core.gtfs.zip`: selected routes from the TokyoGTFS railway feed by Mikołaj Kuranowski
  (https://github.com/MKuranowski/TokyoGTFS). Schedules: Copyright (c) 2019-2025 Akihiko Kusanagi,
  MIT license (https://github.com/nagix/mini-tokyo-3d/). Timetables are unchanged; trips outside
  the selected routes are removed. These schedules are not published by the operators themselves.
- `tokyo-core.osm.pbf`: © OpenStreetMap contributors, cropped from the BBBike Tokyo extract.
  Available under the Open Database License (https://www.openstreetmap.org/copyright).
  This cropped extract is a derivative database and is offered here under the same license.

`build-config.json` limits the graph to service dates 2026-10-05 to 2027-04-05. Prepare new
inputs and rebuild before that date; see `.deploy/transit/README.md`.
