#!/usr/bin/env bash

set -Eeuo pipefail

readonly DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/navio}"
readonly SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly IMAGE_TAG="${IMAGE_TAG:-}"
readonly COMPOSE_FILE="${DEPLOY_ROOT}/compose.production.yml"
readonly ENV_FILE="${DEPLOY_ROOT}/.env"
readonly PREVIOUS_ENV_FILE="${DEPLOY_ROOT}/.env.previous"
readonly TLS_CERT_FILE="${DEPLOY_ROOT}/tls/fullchain.pem"
readonly TLS_KEY_FILE="${DEPLOY_ROOT}/tls/privkey.pem"

if [[ ! "${IMAGE_TAG}" =~ ^[0-9a-f]{40}$ ]]; then
  echo "IMAGE_TAG must be a full 40-character Git commit SHA." >&2
  exit 2
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}; provision VM secrets before deploying." >&2
  exit 2
fi

install -d -m 0755 \
  "${DEPLOY_ROOT}/config" \
  "${DEPLOY_ROOT}/keycloak" \
  "${DEPLOY_ROOT}/nginx" \
  "${DEPLOY_ROOT}/postgres" \
  "${DEPLOY_ROOT}/tls" \
  "${DEPLOY_ROOT}/observability" \
  "${DEPLOY_ROOT}/observability/prometheus/rules" \
  "${DEPLOY_ROOT}/observability/grafana/provisioning/datasources" \
  "${DEPLOY_ROOT}/observability/grafana/provisioning/dashboards" \
  "${DEPLOY_ROOT}/observability/grafana/dashboards"

if [[ ! -r "${TLS_CERT_FILE}" || ! -r "${TLS_KEY_FILE}" ]]; then
  echo "Missing readable TLS certificate files in ${DEPLOY_ROOT}/tls." >&2
  echo "Provision fullchain.pem and privkey.pem before deploying OAuth2." >&2
  exit 2
fi

install -m 0644 "${SOURCE_ROOT}/.deploy/compose.production.yml" "${COMPOSE_FILE}"
install -m 0644 "${SOURCE_ROOT}/.deploy/config/"*.yml "${DEPLOY_ROOT}/config/"
install -m 0644 "${SOURCE_ROOT}/.deploy/keycloak/navio-realm.json" \
  "${DEPLOY_ROOT}/keycloak/navio-realm.json"
install -m 0644 "${SOURCE_ROOT}/.deploy/nginx/navio.conf" "${DEPLOY_ROOT}/nginx/navio.conf"
install -m 0644 "${SOURCE_ROOT}/.deploy/postgres/init-keycloak.sql" "${DEPLOY_ROOT}/postgres/init-keycloak.sql"

# Observability: production-only collector configuration lives in .deploy,
# while alert rules and dashboards are shared with the local stack.
install -m 0644 "${SOURCE_ROOT}/.deploy/observability/prometheus.yml" "${DEPLOY_ROOT}/observability/prometheus.yml"
install -m 0644 "${SOURCE_ROOT}/.deploy/observability/loki-config.yaml" "${DEPLOY_ROOT}/observability/loki-config.yaml"
install -m 0644 "${SOURCE_ROOT}/.deploy/observability/alloy-config.alloy" "${DEPLOY_ROOT}/observability/alloy-config.alloy"
install -m 0644 "${SOURCE_ROOT}/.deploy/observability/grafana/datasources.yml" \
  "${DEPLOY_ROOT}/observability/grafana/provisioning/datasources/datasources.yml"
install -m 0644 "${SOURCE_ROOT}/.deploy/observability/grafana/dashboards.yml" \
  "${DEPLOY_ROOT}/observability/grafana/provisioning/dashboards/dashboards.yml"
install -m 0644 "${SOURCE_ROOT}/prometheus/rules/"*.yml "${DEPLOY_ROOT}/observability/prometheus/rules/"
install -m 0644 "${SOURCE_ROOT}/grafana/dashboards/"*.json "${DEPLOY_ROOT}/observability/grafana/dashboards/"

cp "${ENV_FILE}" "${PREVIOUS_ENV_FILE}"
chmod 0600 "${PREVIOUS_ENV_FILE}"

if grep -q '^NAVIO_IMAGE_TAG=' "${ENV_FILE}"; then
  sed -i "s/^NAVIO_IMAGE_TAG=.*/NAVIO_IMAGE_TAG=${IMAGE_TAG}/" "${ENV_FILE}"
else
  printf '\nNAVIO_IMAGE_TAG=%s\n' "${IMAGE_TAG}" >> "${ENV_FILE}"
fi

compose() {
  docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" "$@"
}

rollback() {
  local previous_image
  local previous_prefix
  local previous_tag
  previous_prefix="$(sed -n 's/^NAVIO_IMAGE_PREFIX=//p' "${PREVIOUS_ENV_FILE}" | tail -n 1)"
  previous_tag="$(sed -n 's/^NAVIO_IMAGE_TAG=//p' "${PREVIOUS_ENV_FILE}" | tail -n 1)"
  previous_image="${previous_prefix}-configuration-server:${previous_tag}"

  if [[ "${previous_tag}" =~ ^[0-9a-f]{40}$ ]] \
    && [[ "${previous_tag}" != "${IMAGE_TAG}" ]] \
    && docker image inspect "${previous_image}" >/dev/null 2>&1; then
    echo "Deployment failed; rolling back to ${previous_tag}." >&2
    cp "${PREVIOUS_ENV_FILE}" "${ENV_FILE}"
    chmod 0600 "${ENV_FILE}"
    compose up -d --remove-orphans --wait --wait-timeout 420 || true
  else
    echo "Deployment failed; no runnable prior release is available." >&2
  fi
}

trap rollback ERR

compose config --quiet
compose pull

# docker-entrypoint-initdb.d runs only for a brand-new volume. Create the
# Keycloak schema explicitly as well so upgrading an existing Navio database
# cannot fail before Keycloak starts.
compose up -d --wait --wait-timeout 120 postgres
compose exec -T postgres sh -ec \
  'psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --set ON_ERROR_STOP=1 --command "CREATE SCHEMA IF NOT EXISTS keycloak AUTHORIZATION CURRENT_USER"'

compose up -d --remove-orphans --wait --wait-timeout 420

curl --fail --silent --show-error \
  --retry 10 --retry-delay 3 --retry-connrefused \
  --resolve navio.sit.kmutt.ac.th:443:127.0.0.1 \
  https://navio.sit.kmutt.ac.th/health >/dev/null

# A healthy gateway alone does not prove authentication is usable. Confirm the
# imported realm is discoverable and the user route is protected (not missing
# and not accidentally public) before declaring the release successful.
curl --fail --silent --show-error \
  --retry 10 --retry-delay 3 --retry-connrefused \
  --resolve navio.sit.kmutt.ac.th:443:127.0.0.1 \
  https://navio.sit.kmutt.ac.th/realms/navio/.well-known/openid-configuration >/dev/null

readonly USER_ROUTE_STATUS="$(curl --silent --show-error \
  --output /dev/null --write-out '%{http_code}' \
  --resolve navio.sit.kmutt.ac.th:443:127.0.0.1 \
  https://navio.sit.kmutt.ac.th/v1/users/me)"
if [[ "${USER_ROUTE_STATUS}" != "401" ]]; then
  echo "Expected anonymous /v1/users/me to return 401; got ${USER_ROUTE_STATUS}." >&2
  exit 1
fi

trap - ERR

compose ps
docker image prune --all --force --filter "until=168h" >/dev/null

echo "Navio backend deployed successfully at ${IMAGE_TAG}."
