# syntax=docker/dockerfile:1.7

# The patched upstream release is source-only:
# https://github.com/minio/minio/releases/tag/RELEASE.2025-10-15T17-29-55Z
FROM golang:1.25-bookworm AS build
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go install github.com/minio/minio@RELEASE.2025-10-15T17-29-55Z

FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 10001 navio \
    && useradd --system --uid 10001 --gid navio --home-dir /data navio \
    && mkdir /data && chown navio:navio /data
COPY --from=build /go/bin/minio /usr/local/bin/minio
USER navio
ENV GOMEMLIMIT=256MiB
VOLUME /data
EXPOSE 9000
ENTRYPOINT ["minio"]
