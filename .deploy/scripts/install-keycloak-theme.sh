#!/usr/bin/env bash

set -Eeuo pipefail

readonly THEME_SOURCE="$1"
readonly THEME_TARGET="$2"

# Both the file names and their contents affect the revision. Compose uses this
# revision to recreate Keycloak only when its cached theme actually changes.
THEME_REVISION="$(
  cd "${THEME_SOURCE}"
  find login -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d ' ' -f 1
)"
readonly THEME_REVISION

while IFS= read -r -d '' theme_file; do
  install -D -m 0644 "${THEME_SOURCE}/${theme_file}" "${THEME_TARGET}/${theme_file}"
done < <(cd "${THEME_SOURCE}" && find login -type f -print0)

# Keycloak and browsers cache resource URLs. A new file name avoids reusing a
# previous release's compressed CSS or the browser's month-long cached copy.
install -m 0644 "${THEME_SOURCE}/login/resources/css/navio.css" \
  "${THEME_TARGET}/login/resources/css/navio-${THEME_REVISION}.css"
sed -i "s|^styles=.*|styles=css/styles.css css/navio-${THEME_REVISION}.css|" \
  "${THEME_TARGET}/login/theme.properties"

printf '%s\n' "${THEME_REVISION}"
