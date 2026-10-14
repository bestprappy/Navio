# Self-hosted transit fallback

Navio can use OpenTripPlanner (OTP) when Google returns no transit journey or its transit provider is unavailable. The adapter uses the existing journey, step and saved route contracts. Road routing stays with Google. Each provider has a separate circuit breaker; cache keys include the configured graph revision. Unsupported vehicle modes are detected from the graph's route inventory and do not count as outages.

The integration is disabled by default in service configuration and enabled in production by `compose.production.yml`. It accepts coordinates worldwide, but can only supply networks and service dates represented by the loaded GTFS and street data. The production graph covers six central Tokyo rail lines, not all of Japan or every country. It includes published schedules and real OSM walking paths. Fares and real-time delay information are not supplied by this feed.

## Production

The `transit-router` image (`.deploy/docker/transit-router.Dockerfile`) builds the graph in CI from the committed inputs in `.deploy/transit/tokyo-core/` (see its `NOTICE.md` for sources and licenses) and serves it with OTP 2.10.0. Every release rebuilds and deploys it with the other images; the VM needs no data files. Mobility reaches it at `http://transit-router:8080/otp/gtfs/v1`; it has no public port.

- **Service window:** `build-config.json` serves 2026-10-05 to 2027-04-05. Before that ends, prepare fresh inputs, update `build-config.json`, and change `NAVIO_OTP_NETWORK_ID` in `compose.production.yml`. A full-year window exhausted an 8 GB local Docker VM during the build; six months built and served within limits.
- **Memory:** the six-month graph serves in about 360 MB resident; the container is limited to 768 MB with a 512 MB heap.
- **Switch off without a release:** set `NAVIO_OTP_ENABLED=false` in `/opt/navio/.env` and recreate `mobility-and-ev-service`. Google routing is unaffected either way.
- **Changing coverage:** replace the inputs with `scripts/transit/prepare-otp-data.py`, build the image locally (`docker build -f .deploy/docker/transit-router.Dockerfile .`), verify journeys with real dates, then update the network ID and release.

## Data

- [TokyoGTFS railway feed](https://mkuran.pl/gtfs/tokyo/rail.zip), [publisher and data license](https://github.com/MKuranowski/TokyoGTFS/blob/main/readme.md#railway). The railway dataset uses schedules from mini-tokyo-3d under MIT: Copyright (c) 2019-2025 Akihiko Kusanagi. The generator's GPL license is separate from the resulting railway data license; Navio uses the published data, not the generator code.
- [Tokyo OSM extract](https://download.bbbike.org/osm/bbbike/Tokyo/Tokyo.osm.pbf), [OpenStreetMap copyright and ODbL](https://www.openstreetmap.org/copyright). Navio shows the route attribution on the planner and public Explore maps when OTP geometry is drawn.
- MLIT [N02 railway GeoJSON](https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N02-2023.html) contains railway/station geometry and names, but no departure times or service calendars. It cannot replace GTFS schedules. The downloaded 2023 archive was inspected; it is not an input to this routing graph.

Keep source licenses and attribution with every dataset. For new regions, obtain suitable licensed GTFS and OSM inputs, inspect the feed's valid dates and operator coverage, and verify real journeys before enabling that region. A country-wide line map or feed-directory entry does not prove timetable coverage.

## Prepare a graph

Use Java 25 and the pinned [OTP 2.10.0 shaded jar](https://repo.maven.apache.org/maven2/org/opentripplanner/otp-shaded/2.10.0/otp-shaded-2.10.0.jar). Keep downloaded data, graphs and logs outside the git workspace. Download the feeds above to your chosen data directory. Install `scripts/transit/requirements.txt` into a virtual environment if cropping streets.

`scripts/transit/prepare-otp-data.py --gtfs <feed.zip> --osm <streets.osm.pbf> --output <graph-directory>` prepares complete inputs. Optional `--routes` selects entire published routes; `--bounds WEST SOUTH EAST NORTH` crops streets, retaining whole ways and referenced nodes. Calendars, attribution and original timetable values are preserved. The output records source hashes and selection limits. Rebuild the graph after preparing new inputs; the script does not replace a running graph.

The memory-bounded local check selected `Toei.Oedo,Toei.Asakusa,Toei.Shinjuku,TokyoMetro.Marunouchi,TokyoMetro.Hanzomon,JR-East.ChuoSobuLocal` and street bounds `139.68 35.65 139.84 35.74`. Other Tokyo operators and regional Japan routes require larger/additional inputs.

The verification graph's `build-config.json` additionally restricts `transitServiceStart` to `2026-10-01` and `transitServiceEnd` to `2026-11-01`. The downloaded feed's calendar extends further, but that saved graph serves only the build interval. Choose and record an appropriate service interval when building a candidate for ongoing use; rebuild before its interval ends.

```powershell
# First build/save, then load/serve; the helper runs those phases separately.
./scripts/transit/start-otp.ps1 -DataDirectory <graph-directory> -JarPath <otp-jar> -Build -Port 18801 -HeapMegabytes 1024
```

For subsequent starts, omit `-Build`. The local router binds only to 127.0.0.1 and refuses occupied ports. The helper records its JVM PID and logs in the graph directory. Choose heap sizes according to the graph; the small verified graph served with 640 MB. Larger graphs need more memory and street coverage. Refresh GTFS and rebuild before service dates expire; replace the graph only after validating the candidate. Keep the previous working graph for rollback.

OTP 2.10's combined build/save/serve path produced an empty RAPTOR index in the local check; loading the saved graph in a fresh process fixed it. Its Grizzly HTTP endpoint also mishandled the JDK client's h2c request body. The backend's dedicated OTP client uses HTTP/1.1 and bounded timeouts.

## Enable locally

After the router is ready, enable it for the Mobility service:

```powershell
$env:NAVIO_OTP_ENABLED = 'true'
$env:NAVIO_OTP_ENDPOINT = 'http://localhost:18801/otp/gtfs/v1'
$env:NAVIO_OTP_NETWORK_ID = 'tokyo-core-20261005'
./navio.cmd start mobility
```

The local runner reads these three settings from the shell first, then from the ignored `server/mobility-and-ev-service/.env.local`. Saving them in that local file preserves activation across later service starts; `NAVIO_OTP_ENABLED=false` in the shell explicitly disables it. The runner forwards their direct Spring property names, so other services do not need restarting. Use a new network ID whenever rebuilding/replacing the graph; restart Mobility to clear its network inventory and separate the new route cache.

The local file has the verified Tokyo endpoint and network ID enabled, and the shared Mobility service is now healthy with those settings. Actual app requests through Next `/api/routes/directions` and the gateway confirm Tokyo Tower -> Shinjuku City via Toei Oedo and Shinjuku City -> Tokyo Skytree. Driving and Taipei transit still work. Production is unchanged.

The first shared restart was blocked by automatic review. The user's manual restart then stopped the old process but hit a shutdown race: a stale port snapshot followed by an absent process was incorrectly treated as a changed owner. The runner now accepts an already exited process, still rejects an unrelated owner/launcher and refuses replacement if the port remains occupied. After confirming the port was free, the authorized start succeeded. Ten isolated process-operation regressions cover these cases.

## Containers and verification

Production runs the router from the `transit-router` image described under **Production** above; the former mount-a-graph overlay was removed.

An explicitly enabled live backend check is `OpenTripPlannerRoutesAdapterTests#mapsLiveTokyoGraphWhenExplicitlyEnabled` with `-Dnavio.test.otp.endpoint=http://localhost:18801/otp/gtfs/v1`. Ordinary unit tests do not contact the router. `client/tests/planner/open-transit.browser.mjs` uses an isolated synthetic account and intercepted trip writes; directions pass unchanged through the actual Next/gateway/Mobility path by default. An explicit `NAVIO_TEST_MOBILITY_ORIGIN` diagnoses a separate API instead. Set `NAVIO_TEST_TOKYO_ROUTE=tower-shinjuku` for the user's Tokyo Tower -> Shinjuku City route. It checks directions, source attribution, save/reload and mobile/light/dark presentation. No real account or trip writes are made. The shutdown guard regression is `powershell -NoProfile -File scripts/local/tests/mobility-restart.tests.ps1`, with all process/file operations mocked.

The planner currently searches the present departure time unless an API caller supplies `departureTime`. Existing bounded departure support is preserved; date/time selection in the product UI is separate work. No schedule is synthesized or date-shifted to make an absent journey appear valid.
