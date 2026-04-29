#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)

# shellcheck source=./lib/selfhost-common.sh
source "${SCRIPT_DIR}/lib/selfhost-common.sh"

SERVER_ENV="${ROOT_DIR}/apps/server/.env"
SERVER_EXAMPLE="${ROOT_DIR}/apps/server/.env.example"
WEB_ENV="${ROOT_DIR}/apps/web/.env"
WEB_EXAMPLE="${ROOT_DIR}/apps/web/.env.example"

generate_secret() {
  local length="${1:-48}"
  local secret=""

  if command_exists openssl; then
    secret="$(openssl rand -base64 64 | tr -dc 'A-Za-z0-9' | cut -c1-"$length")"
  else
    secret="$(
      set +o pipefail
      LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$length"
    )"
  fi

  if [[ -z "$secret" ]]; then
    die "Failed to generate a secure random secret."
  fi

  printf '%s\n' "$secret"
}

set_env_value() {
  local file="$1" key="$2" value="$3"
  local tmp
  tmp="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    $0 ~ "^" key "=" { print key "=" value; next }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

copy_env_file() {
  local src="$1" dst="$2" label="$3"

  if [[ ! -f "$src" ]]; then
    die "Example file not found: ${src}"
  fi

  if [[ -f "$dst" ]]; then
    info "${label} already exists — skipping (delete it to reset)"
    return 0
  fi

  cp "$src" "$dst"
  info "Created ${label}"
}

fill_value() {
  local file="$1" key="$2" value="$3"
  local current
  current="$(default_value "$file" "$key" "")"

  if [[ -n "$current" ]]; then
    return 0
  fi

  # Replace blank KEY= line, or append if key absent entirely
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    set_env_value "$file" "$key" "$value"
  else
    printf '\n%s=%s\n' "$key" "$value" >> "$file"
  fi

  info "Set ${key}"
}

fill_secret() {
  local file="$1" key="$2"
  local current
  current="$(default_value "$file" "$key" "")"

  # Replace if absent or shorter than the minimum required length
  if [[ ${#current} -ge 32 ]]; then
    return 0
  fi

  local secret
  secret="$(generate_secret 64)"

  if grep -q "^${key}=" "$file" 2>/dev/null; then
    set_env_value "$file" "$key" "$secret"
  else
    printf '\n%s=%s\n' "$key" "$secret" >> "$file"
  fi

  info "Generated ${key}"
}

main() {
  info "Setting up local development environment"

  copy_env_file "$SERVER_EXAMPLE" "$SERVER_ENV" "apps/server/.env"
  copy_env_file "$WEB_EXAMPLE" "$WEB_ENV" "apps/web/.env"

  fill_secret "$SERVER_ENV" "BETTER_AUTH_SECRET"
  fill_secret "$SERVER_ENV" "CAPTURE_SUBMIT_TOKEN_SECRET"
  fill_value  "$SERVER_ENV" "BETTER_AUTH_URL"        "http://localhost:3000"

  fill_value  "$WEB_ENV" "NEXT_PUBLIC_SITE_URL"   "http://localhost:3001"
  fill_value  "$WEB_ENV" "NEXT_PUBLIC_APP_URL"    "http://localhost:3001"
  fill_value  "$WEB_ENV" "NEXT_PUBLIC_SERVER_URL" "http://localhost:3000"

  # Always disable payments for local dev — Polar token won't be valid
  if grep -q "^ENABLE_PAYMENTS=" "$SERVER_ENV" 2>/dev/null; then
    set_env_value "$SERVER_ENV" "ENABLE_PAYMENTS" "false"
  else
    printf '\nENABLE_PAYMENTS=false\n' >> "$SERVER_ENV"
  fi
  info "Set ENABLE_PAYMENTS=false"

  fill_value  "$SERVER_ENV" "STORAGE_ENDPOINT"          "http://localhost:9000"
  fill_value  "$SERVER_ENV" "STORAGE_ACCESS_KEY_ID"     "rustfsadmin"
  fill_value  "$SERVER_ENV" "STORAGE_SECRET_ACCESS_KEY" "rustfsadmin"
  fill_value  "$SERVER_ENV" "STORAGE_BUCKET"            "crikket"
  fill_value  "$SERVER_ENV" "STORAGE_REGION"            "auto"
  fill_value  "$SERVER_ENV" "STORAGE_ADDRESSING_STYLE"  "path"
  fill_value  "$SERVER_ENV" "STORAGE_PUBLIC_URL"        "http://localhost:9000"

  info ""
  info "Done. Remaining manual step:"
  info "  Set DATABASE_URL in apps/server/.env, then:"
  info "  bun run db:push && bun run dev"
  info ""
  info "For docs or extension, copy the .env.example files manually:"
  info "  cp apps/docs/.env.example apps/docs/.env"
  info "  cp apps/extension/.env.example apps/extension/.env"
}

main "$@"
