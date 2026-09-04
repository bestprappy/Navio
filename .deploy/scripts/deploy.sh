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

require_env_value() {
  local description="$2"
  local variable_name="$1"
  local value

  value="$(sed -n "s/^${variable_name}=//p" "${ENV_FILE}" | tail -n 1)"
  value="${value//$'\r'/}"
  value="${value//[[:space:]]/}"
  value="${value//\"/}"
  value="${value//\'/}"

  if [[ -z "${value}" ]]; then
    echo "Missing non-empty ${variable_name} in ${ENV_FILE}." >&2
    echo "${description}" >&2
    exit 2
  fi
}

require_env_value \
  "GOOGLE_MAPS_SERVER_API_KEY" \
  "Provision a server-side key for Places API (New) and Routes API before deploying."
require_env_value \
  "GOOGLE_OAUTH_CLIENT_ID" \
  "Provision a Google OAuth web client for Navio sign-in before deploying."
require_env_value \
  "GOOGLE_OAUTH_CLIENT_SECRET" \
  "Provision the matching Google OAuth client secret before deploying."

install -d -m 0755 \
  "${DEPLOY_ROOT}/config" \
  "${DEPLOY_ROOT}/keycloak" \
  "${DEPLOY_ROOT}/nginx" \
  "${DEPLOY_ROOT}/postgres" \
  "${DEPLOY_ROOT}/tls" \
  "${DEPLOY_ROOT}/certbot-webroot" \
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

configure_google_identity_provider() {
  compose exec -T keycloak bash -euc '
    kcadm="/opt/keycloak/bin/kcadm.sh"
    "${kcadm}" config credentials \
      --server http://localhost:8080 \
      --realm master \
      --user "${KC_BOOTSTRAP_ADMIN_USERNAME}" \
      --password "${KC_BOOTSTRAP_ADMIN_PASSWORD}" >/dev/null

    provider_path="identity-provider/instances/google"
    provider_settings=(
      -r "${KEYCLOAK_REALM}"
      -s alias=google
      -s displayName=Google
      -s providerId=google
      -s enabled=true
      -s trustEmail=true
      -s storeToken=false
      -s addReadTokenRoleOnCreate=false
      -s linkOnly=false
      -s hideOnLogin=true
      -s "firstBrokerLoginFlowAlias=first broker login"
      -s "config.clientId=${GOOGLE_OAUTH_CLIENT_ID}"
      -s "config.clientSecret=${GOOGLE_OAUTH_CLIENT_SECRET}"
      -s "config.defaultScope=openid profile email"
      -s "config.syncMode=IMPORT"
      -s "config.useJwksUrl=\"true\""
    )

    if "${kcadm}" get "${provider_path}" -r "${KEYCLOAK_REALM}" >/dev/null 2>&1; then
      "${kcadm}" update "${provider_path}" "${provider_settings[@]}" >/dev/null
    else
      "${kcadm}" create identity-provider/instances "${provider_settings[@]}" >/dev/null
    fi

    "${kcadm}" update "realms/${KEYCLOAK_REALM}" \
      -s registrationAllowed=false >/dev/null
  '
}

reload_edge_proxy() {
  # NGINX resolves Docker service names when its configuration is loaded. The
  # application containers are recreated for every image tag, while NGINX can
  # stay running with their old addresses and return 502 for a healthy stack.
  compose exec -T nginx nginx -t
  compose exec -T nginx nginx -s reload
}

deployment_diagnostics() {
  local container_id
  local health
  local service
  local state

  echo "Deployment diagnostics:" >&2
  compose ps --all >&2 || true

  while IFS= read -r service; do
    container_id="$(compose ps --all -q "${service}" 2>/dev/null || true)"
    [[ -n "${container_id}" ]] || continue

    state="$(docker inspect --format '{{.State.Status}}' "${container_id}" 2>/dev/null || true)"
    health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
      "${container_id}" 2>/dev/null || true)"

    if [[ "${state}" != "running" || "${health}" == "unhealthy" ]]; then
      echo "Diagnostics for ${service} (state=${state:-unknown}, health=${health:-unknown}):" >&2
      docker inspect --format '{{json .State}}' "${container_id}" >&2 || true
      compose logs --no-color --tail 200 "${service}" >&2 || true
    fi
  done < <(compose config --services)
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
    if ! compose up -d --remove-orphans --wait --wait-timeout 420; then
      echo "Rollback did not restore a healthy stack." >&2
      deployment_diagnostics
    elif ! reload_edge_proxy; then
      echo "Rollback restored the stack, but NGINX could not reload its upstream addresses." >&2
      deployment_diagnostics
    fi
  else
    echo "Deployment failed; no runnable prior release is available." >&2
  fi
}

handle_deploy_error() {
  local exit_code=$?

  trap - ERR
  deployment_diagnostics
  rollback
  exit "${exit_code}"
}

trap handle_deploy_error ERR

compose config --quiet
compose pull

# docker-entrypoint-initdb.d runs only for a brand-new volume. Create the
# Keycloak schema explicitly as well so upgrading an existing Navio database
# cannot fail before Keycloak starts.
compose up -d --wait --wait-timeout 120 postgres
compose exec -T postgres sh -ec \
  'psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --set ON_ERROR_STOP=1 --command "CREATE SCHEMA IF NOT EXISTS keycloak AUTHORIZATION CURRENT_USER"'

compose up -d --remove-orphans --wait --wait-timeout 420
configure_google_identity_provider
reload_edge_proxy

curl --fail --silent --show-error \
  --retry 10 --retry-delay 3 --retry-connrefused \
  --cacert "${TLS_CERT_FILE}" \
  --resolve navio.sit.kmutt.ac.th:443:127.0.0.1 \
  https://navio.sit.kmutt.ac.th/health >/dev/null

# A healthy gateway alone does not prove authentication is usable. Confirm the
# imported realm is discoverable and the user route is protected (not missing
# and not accidentally public) before declaring the release successful.
curl --fail --silent --show-error \
  --retry 10 --retry-delay 3 --retry-connrefused \
  --cacert "${TLS_CERT_FILE}" \
  --resolve navio.sit.kmutt.ac.th:443:127.0.0.1 \
  https://navio.sit.kmutt.ac.th/realms/navio/.well-known/openid-configuration >/dev/null

readonly USER_ROUTE_STATUS="$(curl --silent --show-error \
  --output /dev/null --write-out '%{http_code}' \
  --cacert "${TLS_CERT_FILE}" \
  --resolve navio.sit.kmutt.ac.th:443:127.0.0.1 \
  https://navio.sit.kmutt.ac.th/v1/users/me)"
if [[ "${USER_ROUTE_STATUS}" != "401" ]]; then
  echo "Expected anonymous /v1/users/me to return 401; got ${USER_ROUTE_STATUS}." >&2
  exit 1
fi

for auth_path in sign-in sign-up; do
  if ! curl --fail --silent --show-error \
    --cacert "${TLS_CERT_FILE}" \
    --resolve navio.sit.kmutt.ac.th:443:127.0.0.1 \
    "https://navio.sit.kmutt.ac.th/${auth_path}" | grep -q 'Continue with Google'; then
    echo "Expected /${auth_path} to render the Google authentication action." >&2
    exit 1
  fi
done

readonly GOOGLE_OAUTH_COOKIE_JAR="$(mktemp)"
trap 'rm -f "${GOOGLE_OAUTH_COOKIE_JAR}"' EXIT

readonly GOOGLE_BROKER_REDIRECT="$(curl --fail --silent --show-error \
  --output /dev/null --write-out '%{redirect_url}' \
  --cookie-jar "${GOOGLE_OAUTH_COOKIE_JAR}" \
  --cacert "${TLS_CERT_FILE}" \
  --resolve navio.sit.kmutt.ac.th:443:127.0.0.1 \
  --get \
  --data-urlencode 'client_id=navio-web' \
  --data-urlencode 'redirect_uri=https://navio.sit.kmutt.ac.th/api/auth/callback/keycloak' \
  --data-urlencode 'response_type=code' \
  --data-urlencode 'scope=openid email profile' \
  --data-urlencode 'state=deployment-smoke' \
  --data-urlencode 'nonce=deployment-smoke' \
  --data-urlencode 'code_challenge_method=S256' \
  --data-urlencode 'code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM' \
  --data-urlencode 'kc_idp_hint=google' \
  'https://navio.sit.kmutt.ac.th/realms/navio/protocol/openid-connect/auth')"
if [[ ! "${GOOGLE_BROKER_REDIRECT}" =~ ^https://navio\.sit\.kmutt\.ac\.th/realms/navio/broker/google/login ]]; then
  echo "Google OAuth broker was not selected by the Navio authorization request." >&2
  exit 1
fi

readonly GOOGLE_AUTH_REDIRECT="$(curl --fail --silent --show-error \
  --output /dev/null --write-out '%{redirect_url}' \
  --cookie "${GOOGLE_OAUTH_COOKIE_JAR}" \
  --cacert "${TLS_CERT_FILE}" \
  --resolve navio.sit.kmutt.ac.th:443:127.0.0.1 \
  "${GOOGLE_BROKER_REDIRECT}")"
if [[ ! "${GOOGLE_AUTH_REDIRECT}" =~ ^https://accounts\.google\.com/ ]]; then
  echo "Google OAuth broker did not redirect to accounts.google.com." >&2
  exit 1
fi
rm -f "${GOOGLE_OAUTH_COOKIE_JAR}"
trap - EXIT

trap - ERR

compose ps
docker image prune --all --force --filter "until=168h" >/dev/null

echo "Navio backend deployed successfully at ${IMAGE_TAG}."
