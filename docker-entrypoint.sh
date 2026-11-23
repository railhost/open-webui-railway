#!/usr/bin/env bash
# Starts Open WebUI on $PORT with its data on the Railway volume, as an
# unprivileged user. Open WebUI creates the admin from WEBUI_ADMIN_EMAIL and
# WEBUI_ADMIN_PASSWORD before it takes the first request, so nobody can claim
# a fresh instance through the signup page.
set -euo pipefail

DATA_DIR="${DATA_DIR:-/data}"
APP_USER=webui

log() { echo "[railway-entrypoint] $*"; }

# Railway mounts volumes as root. Fix ownership once, then drop privileges.
if [ "$(id -u)" = 0 ]; then
  mkdir -p "$DATA_DIR"
  rm -rf "$DATA_DIR/lost+found"
  if [ "$(stat -c %U "$DATA_DIR")" != "$APP_USER" ]; then
    log "Giving $APP_USER ownership of $DATA_DIR"
    chown -R "$APP_USER:$APP_USER" "$DATA_DIR"
  fi
  exec setpriv --reuid="$APP_USER" --regid="$APP_USER" --init-groups "$0" "$@"
fi

if [ -z "${WEBUI_URL:-}" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export WEBUI_URL="https://$RAILWAY_PUBLIC_DOMAIN"
fi
export WEBUI_ADMIN_EMAIL="${WEBUI_ADMIN_EMAIL:-admin@localhost}"

# Without a password Open WebUI skips the admin, and the first visitor to open
# the page becomes admin. Refuse to start a fresh instance that way.
if [ -z "${WEBUI_ADMIN_PASSWORD:-}" ] && [ -z "${DATABASE_URL:-}" ] && [ ! -f "$DATA_DIR/webui.db" ]; then
  log "ERROR: WEBUI_ADMIN_PASSWORD is empty. Set it so the first boot creates the admin account."
  exit 1
fi
# A missing secret would be regenerated and lost on every redeploy, signing
# everyone out. Keep a generated one on the volume instead.
if [ -z "${WEBUI_SECRET_KEY:-}" ]; then
  log "WARNING: WEBUI_SECRET_KEY is not set. Using a key stored on the volume."
  export WEBUI_SECRET_KEY_FILE="$DATA_DIR/.webui_secret_key"
fi

log "Starting Open WebUI $(sed -n 's/.*"version": "\(.*\)".*/\1/p' /app/package.json | head -n1) on port ${PORT:-8080}"
exec /app/backend/start.sh "$@"
