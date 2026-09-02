# syntax=docker/dockerfile:1.7

FROM node:22-bookworm-slim AS deps

WORKDIR /workspace

COPY client/package.json client/package-lock.json ./

RUN --mount=type=cache,target=/root/.npm npm ci

FROM node:22-bookworm-slim AS build

WORKDIR /workspace

COPY --from=deps /workspace/node_modules ./node_modules
COPY client/ ./

# NEXT_PUBLIC_* values are inlined into the browser bundle by `next build`, so
# they must be present here rather than at runtime. Anything passed as a build
# arg is baked into the image and readable by anyone who can pull it — only
# genuinely public, referrer-restricted keys belong here. Server-side secrets
# (AUTH_SECRET, AUTH_KEYCLOAK_SECRET) are runtime environment, never build args.
ARG NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=""
ARG NEXT_PUBLIC_GOOGLE_MAPS_MAP_ID=""
ARG NEXT_PUBLIC_MAP_PROVIDER=""
# :- rather than a plain ARG default on purpose. A workflow passes
# --build-arg NAME=<secret>, and an unset repository secret expands to an empty
# string, which OVERRIDES an ARG default. The app reads these with ?? , which
# falls back only on undefined and not on "", so an empty value would reach
# Google Maps as mapId="" and break Advanced Markers. Coercing here keeps a
# missing secret equivalent to never setting the variable.
ENV NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=${NEXT_PUBLIC_GOOGLE_MAPS_API_KEY} \
    NEXT_PUBLIC_GOOGLE_MAPS_MAP_ID=${NEXT_PUBLIC_GOOGLE_MAPS_MAP_ID:-DEMO_MAP_ID} \
    NEXT_PUBLIC_MAP_PROVIDER=${NEXT_PUBLIC_MAP_PROVIDER:-google} \
    NEXT_TELEMETRY_DISABLED=1

RUN npm run build

FROM node:22-bookworm-slim AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 10001 navio \
    && useradd --system --uid 10001 --gid navio --home-dir /app --shell /usr/sbin/nologin navio

WORKDIR /app

# standalone carries its own minimal server.js; static/ and public/ are not
# included in the trace and must be copied alongside it.
COPY --from=build --chown=navio:navio /workspace/.next/standalone ./
COPY --from=build --chown=navio:navio /workspace/.next/static ./.next/static
COPY --from=build --chown=navio:navio /workspace/public ./public

USER navio

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    HOSTNAME=0.0.0.0 \
    PORT=3000

EXPOSE 3000

ENTRYPOINT ["node", "server.js"]
