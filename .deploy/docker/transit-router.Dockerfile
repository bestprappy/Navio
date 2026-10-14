# Self-hosted OpenTripPlanner with the graph baked in, so the VM needs no data files.
# Build and serve run in separate processes: OTP 2.10's combined build+serve path
# produced an empty RAPTOR index locally, while loading the saved graph works.
FROM opentripplanner/opentripplanner:2.10.0 AS graph
COPY .deploy/transit/tokyo-core/build-config.json \
     .deploy/transit/tokyo-core/tokyo-core.gtfs.zip \
     .deploy/transit/tokyo-core/tokyo-core.osm.pbf \
     /var/opentripplanner/
RUN JAVA_OPTS="-Xmx2g" /docker-entrypoint.sh --build --save

FROM opentripplanner/opentripplanner:2.10.0
COPY --from=graph /var/opentripplanner/graph.obj /var/opentripplanner/graph.obj
COPY .deploy/transit/tokyo-core/NOTICE.md /var/opentripplanner/NOTICE.md
EXPOSE 8080
CMD ["--load", "--serve"]
