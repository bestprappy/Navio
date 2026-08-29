#!/usr/bin/env bash

set -Eeuo pipefail

readonly DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/navio}"
readonly SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly IMAGE_TAG="${IMAGE_TAG:-}"
readonly COMPOSE_FILE="${DEPLOY_ROOT}/compose.production.yml"
readonly ENV_FILE="${DEPLOY_ROOT}/.env"
readonly PREVIOUS_ENV_FILE="${DEPLOY_ROOT}/.env.previous"

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
  "${DEPLOY_ROOT}/nginx" \
  "${DEPLOY_ROOT}/postgres"

install -m 0644 "${SOURCE_ROOT}/.deploy/compose.production.yml" "${COMPOSE_FILE}"
install -m 0644 "${SOURCE_ROOT}/.deploy/config/"*.yml "${DEPLOY_ROOT}/config/"
install -m 0644 "${SOURCE_ROOT}/.deploy/nginx/navio.conf" "${DEPLOY_ROOT}/nginx/navio.conf"
install -m 0644 "${SOURCE_ROOT}/.deploy/postgres/init-keycloak.sql" "${DEPLOY_ROOT}/postgres/init-keycloak.sql"

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
compose run --rm --no-deps --user 0:0 --entrypoint chown \
  user-management-service -R 10001:10001 /data
compose up -d --remove-orphans --wait --wait-timeout 420

curl --fail --silent --show-error \
  --retry 10 --retry-delay 3 --retry-connrefused \
  http://127.0.0.1/health >/dev/null

trap - ERR

compose ps
docker image prune --all --force --filter "until=168h" >/dev/null

echo "Navio backend deployed successfully at ${IMAGE_TAG}."
