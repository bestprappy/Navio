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
  "${DEPLOY_ROOT}/keycloak/themes/navio/login/resources/css" \
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
install -m 0644 "${SOURCE_ROOT}/.deploy/keycloak/themes/navio/login/theme.properties" \
  "${DEPLOY_ROOT}/keycloak/themes/navio/login/theme.properties"
install -m 0644 "${SOURCE_ROOT}/.deploy/keycloak/themes/navio/login/resources/css/navio.css" \
  "${DEPLOY_ROOT}/keycloak/themes/navio/login/resources/css/navio.css"
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

configure_keycloak_authentication() {
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

    # navio-web keeps fullScopeAllowed=false, so a realm role reaches the token
    # only if it is in the client'"'"'s scope. With that list empty Keycloak omits
    # realm_access entirely and every token looks unprivileged: the gateway lets
    # plain authenticated calls through, so this surfaces only as empty roles and
    # silently unreachable MODERATOR/ADMIN features. Grant exactly the three
    # Navio roles rather than turning full scope on.
    client_id="$("${kcadm}" get clients -r "${KEYCLOAK_REALM}" \
      -q clientId=navio-web --fields id --format csv --noquotes)"
    for role_name in USER MODERATOR ADMIN; do
      if ! "${kcadm}" get "clients/${client_id}/scope-mappings/realm" \
        -r "${KEYCLOAK_REALM}" --fields name --format csv --noquotes \
        | grep -qx "${role_name}"; then
        role_id="$("${kcadm}" get "roles/${role_name}" -r "${KEYCLOAK_REALM}" \
          --fields id --format csv --noquotes)"
        printf '[{"id":"%s","name":"%s"}]' "${role_id}" "${role_name}" \
          > /tmp/navio-scope-mapping.json
        "${kcadm}" create "clients/${client_id}/scope-mappings/realm" \
          -r "${KEYCLOAK_REALM}" -f /tmp/navio-scope-mapping.json
      fi
    done
    rm -f /tmp/navio-scope-mapping.json

    # verifyEmail must stay off until an SMTP server is configured. With it on,
    # Keycloak defers the password to a post-verification required action, so the
    # registration form ships without password fields and every sign-up dead-ends
    # at SEND_VERIFY_EMAIL_ERROR ("Invalid sender address null"), leaving accounts
    # with no credential at all. Turn this back on in the same change that adds
    # smtpServer, never before.
    "${kcadm}" update "realms/${KEYCLOAK_REALM}" \
      -s registrationAllowed=true \
      -s verifyEmail=false \
      -s loginTheme=navio \
      -s "passwordPolicy=length(12) and notUsername and notEmail and passwordHistory(3)" \
      >/dev/null
  '
}

reload_edge_proxy() {
  # NGINX resolves Docker service names when its configuration is loaded. The
  # application containers are recreated for every image tag, while NGINX can
  # stay running with their old addresses and return 502 for a healthy stack.
  #
  # A reload alone is not always enough. NGINX is the one service whose image
  # never changes, so Compose leaves the container running across every deploy,
  # and navio.conf is bind-mounted as a single file — which Docker pins by inode
  # at mount time. install(1) unlinks and recreates the file, so the container
  # keeps reading the old, now-orphaned inode and `nginx -s reload` silently
  # re-reads stale configuration. Compare what the container actually has
  # against what was just installed, and recreate it when they differ. The same
  # cmp also covers the container being absent on a first deploy.
  if compose exec -T nginx cmp -s /etc/nginx/conf.d/default.conf - \
    < "${DEPLOY_ROOT}/nginx/navio.conf"; then
    compose exec -T nginx nginx -t
    compose exec -T nginx nginx -s reload
  else
    compose up -d --force-recreate --no-deps nginx
  fi
}

verify_authjs_keycloak_start() {
  # Exercise the request path that the browser buttons use, from inside the
  # web container. Host-level Keycloak probes cannot catch broken container
  # DNS, certificate trust, or server-to-server OIDC routing.
  compose exec -T navio-web node <<'NODE'
const localWebOrigin = "http://127.0.0.1:3000";
const internalIssuer = process.env.AUTH_KEYCLOAK_INTERNAL_ISSUER;
const publicIssuer = process.env.AUTH_KEYCLOAK_ISSUER;

if (!internalIssuer || !publicIssuer) {
  throw new Error("Keycloak issuer environment is incomplete in navio-web.");
}

const discoveryResponse = await fetch(
  `${internalIssuer}/.well-known/openid-configuration`,
);
if (!discoveryResponse.ok) {
  throw new Error(
    `Internal Keycloak discovery failed with status ${discoveryResponse.status}.`,
  );
}

const csrfResponse = await fetch(`${localWebOrigin}/api/auth/csrf`);
if (!csrfResponse.ok) {
  throw new Error(`Auth.js CSRF request failed with status ${csrfResponse.status}.`);
}

const csrfBody = await csrfResponse.json();
const csrfCookie = csrfResponse.headers
  .getSetCookie()
  .find((value) => value.includes("authjs.csrf-token="))
  ?.split(";", 1)[0];

if (typeof csrfBody.csrfToken !== "string" || !csrfCookie) {
  throw new Error("Auth.js did not issue a CSRF token and matching cookie.");
}

const signInResponse = await fetch(
  `${localWebOrigin}/api/auth/signin/keycloak`,
  {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Cookie: csrfCookie,
      "X-Auth-Return-Redirect": "1",
    },
    body: new URLSearchParams({
      callbackUrl: "/planner",
      csrfToken: csrfBody.csrfToken,
    }),
  },
);
const signInBody = await signInResponse.json();
const authorizationUrl =
  typeof signInBody.url === "string" ? new URL(signInBody.url) : null;
const expectedAuthorizationUrl = new URL(
  `${publicIssuer}/protocol/openid-connect/auth`,
);
const expectedCallbackUrl =
  `${process.env.AUTH_URL.replace(/\/$/, "")}/api/auth/callback/keycloak`;

if (
  !signInResponse.ok ||
  !authorizationUrl ||
  authorizationUrl.origin !== expectedAuthorizationUrl.origin ||
  authorizationUrl.pathname !== expectedAuthorizationUrl.pathname ||
  authorizationUrl.searchParams.get("client_id") !==
    process.env.AUTH_KEYCLOAK_ID ||
  authorizationUrl.searchParams.get("redirect_uri") !== expectedCallbackUrl ||
  authorizationUrl.searchParams.get("code_challenge_method") !== "S256"
) {
  throw new Error(
    `Auth.js did not return the Keycloak authorization URL (status ${signInResponse.status}).`,
  );
}

console.log("Auth.js Keycloak authorization start verified from navio-web.");
NODE
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

handle_deploy_exit() {
  local exit_code=$?

  trap - EXIT
  if [[ "${exit_code}" -ne 0 ]]; then
    deployment_diagnostics
    rollback
  fi
  exit "${exit_code}"
}

trap handle_deploy_exit EXIT

compose config --quiet
compose pull

# docker-entrypoint-initdb.d runs only for a brand-new volume. Create the
# Keycloak schema explicitly as well so upgrading an existing Navio database
# cannot fail before Keycloak starts.
compose up -d --wait --wait-timeout 120 postgres
compose exec -T postgres sh -ec \
  'psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --set ON_ERROR_STOP=1 --command "CREATE SCHEMA IF NOT EXISTS keycloak AUTHORIZATION CURRENT_USER"'

compose up -d --remove-orphans --wait --wait-timeout 420
configure_keycloak_authentication
reload_edge_proxy
verify_authjs_keycloak_start

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

readonly KEYCLOAK_LOGIN_HTML="$(curl --fail --silent --show-error \
  --cacert "${TLS_CERT_FILE}" \
  --resolve navio.sit.kmutt.ac.th:443:127.0.0.1 \
  --get \
  --data-urlencode 'client_id=navio-web' \
  --data-urlencode 'redirect_uri=https://navio.sit.kmutt.ac.th/api/auth/callback/keycloak' \
  --data-urlencode 'response_type=code' \
  --data-urlencode 'scope=openid email profile' \
  --data-urlencode 'state=deployment-email-login' \
  --data-urlencode 'nonce=deployment-email-login' \
  --data-urlencode 'code_challenge_method=S256' \
  --data-urlencode 'code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM' \
  'https://navio.sit.kmutt.ac.th/realms/navio/protocol/openid-connect/auth')"
if [[ "${KEYCLOAK_LOGIN_HTML}" != *'name="username"'* ]] \
  || [[ "${KEYCLOAK_LOGIN_HTML}" != *'name="password"'* ]] \
  || [[ "${KEYCLOAK_LOGIN_HTML}" != *'navio.css'* ]]; then
  echo "Expected the themed Keycloak email/password login form." >&2
  exit 1
fi

readonly KEYCLOAK_REGISTRATION_HTML="$(curl --fail --silent --show-error \
  --cacert "${TLS_CERT_FILE}" \
  --resolve navio.sit.kmutt.ac.th:443:127.0.0.1 \
  --get \
  --data-urlencode 'client_id=navio-web' \
  --data-urlencode 'redirect_uri=https://navio.sit.kmutt.ac.th/api/auth/callback/keycloak' \
  --data-urlencode 'response_type=code' \
  --data-urlencode 'scope=openid email profile' \
  --data-urlencode 'state=deployment-email-registration' \
  --data-urlencode 'nonce=deployment-email-registration' \
  --data-urlencode 'code_challenge_method=S256' \
  --data-urlencode 'code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM' \
  --data-urlencode 'prompt=create' \
  'https://navio.sit.kmutt.ac.th/realms/navio/protocol/openid-connect/auth')"
if [[ "${KEYCLOAK_REGISTRATION_HTML}" != *'name="email"'* ]] \
  || [[ "${KEYCLOAK_REGISTRATION_HTML}" != *'kc-register-form'* ]] \
  || [[ "${KEYCLOAK_REGISTRATION_HTML}" != *'navio.css'* ]]; then
  echo "Expected the themed Keycloak email registration form." >&2
  exit 1
fi
# The password fields are the regression canary for verifyEmail. Keycloak drops
# them from this form the moment email verification is switched on, which is
# silent until a real user registers and ends up with no credential.
if [[ "${KEYCLOAK_REGISTRATION_HTML}" != *'name="password"'* ]] \
  || [[ "${KEYCLOAK_REGISTRATION_HTML}" != *'name="password-confirm"'* ]]; then
  echo "Registration form has no password fields; verifyEmail is on without SMTP." >&2
  exit 1
fi

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
  auth_page_html="$(curl --fail --silent --show-error \
    --cacert "${TLS_CERT_FILE}" \
    --resolve navio.sit.kmutt.ac.th:443:127.0.0.1 \
    "https://navio.sit.kmutt.ac.th/${auth_path}")"
  expected_email_action='Continue with email &amp; password'
  if [[ "${auth_path}" == "sign-up" ]]; then
    expected_email_action='Sign up with email'
  fi
  if [[ "${auth_page_html}" != *'Continue with Google'* ]] \
    || [[ "${auth_page_html}" != *"${expected_email_action}"* ]]; then
    echo "Expected /${auth_path} to render email/password and Google authentication actions." >&2
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

trap - EXIT

compose ps
docker image prune --all --force --filter "until=168h" >/dev/null

echo "Navio backend deployed successfully at ${IMAGE_TAG}."
