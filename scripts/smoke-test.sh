#!/usr/bin/env bash
# Builds the image, starts Open WebUI with a stand-in OpenAI API
# (docker-compose.yml) and checks what a template user depends on: the app runs
# as an unprivileged user, the API is locked, signup is closed, the generated
# admin login works, a chat gets an answer from the connected model, and chats
# and logins survive a restart. Used locally and by CI. Needs docker, curl,
# python3 and openssl.
set -euo pipefail

cd "$(dirname "$0")/.."
PORT="${SMOKE_PORT:-39400}"
BASE="http://127.0.0.1:$PORT"
EMAIL=admin@example.com
export SMOKE_PORT="$PORT" SMOKE_ADMIN_EMAIL="$EMAIL"
export SMOKE_ADMIN_PASSWORD="smoke-$(openssl rand -hex 12)"
export SMOKE_SECRET_KEY="$(openssl rand -hex 32)"
WORK="$(mktemp -d)"
TOKEN=""

compose() { docker compose -p open-webui-smoke -f docker-compose.yml "$@"; }

cleanup() {
  compose down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  compose logs --tail 80 open-webui >&2 || true
  exit 1
}

# The first boot loads the bundled embedding model, which takes a while.
start() {
  compose up -d >/dev/null 2>&1 || { compose logs --tail 80 >&2; fail "containers did not start"; }
  for _ in $(seq 1 240); do
    [ "$(status /health)" = 200 ] && return 0
    sleep 1
  done
  fail "server did not answer /health"
}

# Usage: status [curl options] <path>. Prints the HTTP status code.
status() {
  local path="${!#}" opts=("${@:1:$#-1}")
  curl -s -o /dev/null -w '%{http_code}' ${opts[@]+"${opts[@]}"} "$BASE$path" 2>/dev/null || true
}
# Usage: api <method> <path> [json body]. Saves the body in $WORK/body, prints the status.
api() {
  local args=(-s -o "$WORK/body" -w '%{http_code}' -X "$1" -H 'Content-Type: application/json')
  [ -n "$TOKEN" ] && args+=(-H "Authorization: Bearer $TOKEN")
  [ $# -ge 3 ] && args+=(--data-binary "$3")
  curl "${args[@]}" "$BASE$2" || true
}
# Usage: field <python expression on j>. Reads $WORK/body as JSON.
field() { python3 -I -c "import json, sys; j = json.load(sys.stdin); print($1)" <"$WORK/body"; }

signin() {
  TOKEN=""
  api POST /api/v1/auths/signin "{\"email\":\"$EMAIL\",\"password\":\"$1\"}"
}

if [ -z "${SKIP_BUILD:-}" ]; then
  compose build open-webui
fi
compose down -v --remove-orphans >/dev/null 2>&1 || true

echo "== first boot"
start
api GET /api/version >/dev/null
echo "Open WebUI $(field 'j["version"]')"
[ "$(compose exec -T open-webui sh -c "stat -c %U /proc/1")" = webui ] || fail "server is not running as the unprivileged user"
[ "$(compose exec -T open-webui sh -c "stat -c %U /data/webui.db")" = webui ] || fail "the database is not on the volume"
! compose logs open-webui 2>&1 | grep -q 'Fetching [0-9]* files' || fail "the bundled embedding model was downloaded again"

echo "== locked without a login"
for path in /api/v1/auths/ /api/models /api/v1/chats/ /api/v1/users/; do
  code="$(status "$path")"
  [ "$code" = 401 ] || [ "$code" = 403 ] || fail "$path is reachable without a login (HTTP $code)"
done
[ "$(api POST /api/chat/completions '{"model":"smoke-model","messages":[{"role":"user","content":"hi"}]}')" != 200 ] \
  || fail "chat works without a login"

echo "== signup is closed"
code="$(api POST /api/v1/auths/signup '{"name":"Stranger","email":"stranger@example.com","password":"stranger-password-123"}')"
[ "$code" = 403 ] || fail "a stranger could sign up (HTTP $code)"
api GET /api/config >/dev/null
[ "$(field 'j["features"]["enable_signup"]')" = False ] || fail "the config still offers signup"
[ "$(field 'j.get("onboarding", False)')" = False ] || fail "the first-run admin setup page is open"

echo "== admin login"
[ "$(signin wrong-password-123)" = 400 ] || fail "a wrong password was not refused"
[ "$(signin "$SMOKE_ADMIN_PASSWORD")" = 200 ] || fail "login with the configured password failed"
TOKEN="$(field 'j["token"]')"
[ "$(field 'j["role"]')" = admin ] || fail "the configured user is not an admin"
[ "$(api GET /api/v1/auths/)" = 200 ] || fail "the session token does not work"

echo "== a chat gets an answer from the connected model"
[ "$(api GET /api/models)" = 200 ] || fail "the model list did not load"
[ "$(field '",".join(m["id"] for m in j["data"])')" = smoke-model ] || fail "the OpenAI connection's model is not listed: $(cat "$WORK/body")"
code="$(api POST /api/chat/completions '{"model":"smoke-model","stream":false,"messages":[{"role":"user","content":"Say hello"}]}')"
[ "$code" = 200 ] || fail "chat completion failed (HTTP $code): $(cat "$WORK/body")"
reply="$(field 'j["choices"][0]["message"]["content"]')"
[ "$reply" = "Hello from the smoke test model." ] || fail "unexpected reply: $reply"

echo "== save a chat"
[ "$(api POST /api/v1/chats/new '{"chat":{"title":"Smoke chat","models":["smoke-model"],"messages":[{"role":"user","content":"Say hello"},{"role":"assistant","content":"Hello from the smoke test model."}]}}')" = 200 ] \
  || fail "saving a chat failed: $(cat "$WORK/body")"
CHAT_ID="$(field 'j["id"]')"

echo "== restart keeps the data"
compose down >/dev/null 2>&1
start
[ "$(api GET /api/v1/auths/)" = 200 ] || fail "the session did not survive a restart"
[ "$(api GET "/api/v1/chats/$CHAT_ID")" = 200 ] || fail "the chat is gone after restart"
[ "$(field 'j["chat"]["title"]')" = "Smoke chat" ] || fail "the chat changed after restart"
[ "$(signin "$SMOKE_ADMIN_PASSWORD")" = 200 ] || fail "login failed after restart"
code="$(api POST /api/v1/auths/signup '{"name":"Stranger","email":"stranger@example.com","password":"stranger-password-123"}')"
[ "$code" = 403 ] || fail "signup opened after restart (HTTP $code)"

echo "PASS"
