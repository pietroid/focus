#!/usr/bin/env bash
# e2e.sh [flow files...]
#
# One isolated end-to-end run of the code in this checkout. It builds and
# starts the backend, the agent and the web app on their own ports, starts
# the Firebase emulators, gives the stack an empty data directory and the
# agent's account (focus.main.agent@gmail.com) in a fresh emulator, drives
# the app in Chrome with Maestro, and
# removes everything it made on the way out. Nothing is deployed anywhere and
# no key is needed.
#
# There is no calendar behind the agent here, so flows tagged `calendar` are
# skipped.
#
# Other knobs:
#   E2E_RECORD=1      record the screen to video.mp4 (Linux, needs DISPLAY + ffmpeg)
#   E2E_OUT=<dir>     where artifacts go (default e2e/artifacts/<timestamp>)
#   E2E_SKIP_BUILD=1  reuse the last server, agent and web builds
set -euo pipefail

E2E_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$E2E_DIR/.." && pwd)"

SERVER_PORT=3100
AGENT_PORT=3101
WEB_PORT=8100
TIMEZONE="${FOCUS_TIMEZONE:-America/Sao_Paulo}"
# Maestro 2.10 ships Chrome DevTools support for Chrome 145-147 only. Selenium
# downloads Chrome for Testing at this version. Move it with MAESTRO_VERSION.
export SE_BROWSER_VERSION="${SE_BROWSER_VERSION:-147}"
export MAESTRO_CLI_NO_ANALYTICS=1 MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true

out="${E2E_OUT:-$E2E_DIR/artifacts/$(date +%Y%m%d-%H%M%S)}"
work="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/focus-e2e.XXXXXX")"
mkdir -p "$out" "$work/threads" "$work/agent"

log() { echo "[e2e] $*"; }
die() { echo "[e2e] error: $*" >&2; exit 1; }
need() { command -v "$1" > /dev/null 2>&1 || die "$1 is not installed. $2"; }

need node "Install Node 22."
need flutter "Install Flutter."
need maestro "Install it: curl -fsSL https://get.maestro.mobile.dev | bash"
need python3 "Install Python 3."

pids=()
recorder=""
uid=""

# The backend and the account script talk to the emulators, never to a real
# Firebase project.
# The project id is the dev flavor's (focus-local-dev), so the tokens the
# dev build gets from the emulator are the ones the backend expects.
firebase_env=(FIREBASE_PROJECT_ID=focus-local-dev FIREBASE_AUTH_EMULATOR_HOST=localhost:9099
  FIRESTORE_EMULATOR_HOST=localhost:8080 GOOGLE_APPLICATION_CREDENTIALS=)
app_env_file="$ROOT/app/env/e2e.json"

# The account the E2E build signs in with by itself, named in e2e.json. It
# only ever exists in this run's emulator, which starts empty every time.
email="$(node -e 'console.log(require(process.argv[1]).TEST_LOGIN_EMAIL)' "$app_env_file")"
password="$(node -e 'console.log(require(process.argv[1]).TEST_LOGIN_PASSWORD)' "$app_env_file")"

cleanup() {
  local status=$?
  set +e
  if [ -n "$recorder" ]; then
    kill -INT "$recorder" 2> /dev/null
    wait "$recorder" 2> /dev/null
  fi
  if [ -n "$uid" ]; then
    log "removing $email"
    (cd "$ROOT/server" && env "${firebase_env[@]}" node scripts/test-account.mjs delete "$email") > /dev/null
  fi
  for pid in ${pids[@]+"${pids[@]}"}; do kill "$pid" 2> /dev/null; done
  wait 2> /dev/null
  rm -rf "$work"
  exit "$status"
}
trap cleanup EXIT

wait_for() {
  local url="$1" name="$2"
  for _ in $(seq 1 90); do
    curl -fsS --max-time 2 "$url" > /dev/null 2>&1 && return 0
    sleep 2
  done
  die "$name did not come up at $url. See $out/logs/$name.log"
}

mkdir -p "$out/logs"
log "account: $email, artifacts: $out"

if [ "${E2E_SKIP_BUILD:-0}" != 1 ]; then
  log "building server and agent"
  (cd "$ROOT/server" && npm ci --no-audit --no-fund --silent && npm run build --silent) > "$out/logs/build-node.log" 2>&1 \
    || die "the node build failed. See $out/logs/build-node.log"
  (cd "$ROOT/agent" && npm ci --no-audit --no-fund --silent && npm run build --silent) >> "$out/logs/build-node.log" 2>&1 \
    || die "the node build failed. See $out/logs/build-node.log"

  log "building the web app with $(basename "$app_env_file")"
  node -e '
    const env = require(process.argv[1]);
    env.API_BASE_URL = process.argv[2];
    require("fs").writeFileSync(process.argv[3], JSON.stringify(env));
  ' "$app_env_file" "http://localhost:$SERVER_PORT" "$work/app-env.json"
  (cd "$ROOT/app" && flutter pub get > /dev/null && flutter build web --release --dart-define-from-file "$work/app-env.json") \
    > "$out/logs/build-web.log" 2>&1 || die "the web build failed. See $out/logs/build-web.log"
fi

log "starting the Firebase emulators"
(cd "$E2E_DIR" && npx --yes firebase-tools@latest emulators:start --project focus-local-dev) > "$out/logs/emulators.log" 2>&1 &
pids+=($!)
wait_for http://localhost:9099/ emulators

log "creating $email in the emulator"
account="$(cd "$ROOT/server" && env "${firebase_env[@]}" E2E_PASSWORD="$password" \
  node scripts/test-account.mjs create "$email" "Focus Agent")"
uid="$(node -e 'console.log(JSON.parse(process.argv[1]).uid)' "$account")"

log "starting the agent on :$AGENT_PORT"
agent_env=(PORT="$AGENT_PORT" AGENT_DATA_DIR="$work/agent" TZ="$TIMEZONE" FOCUS_TIMEZONE="$TIMEZONE")
(cd "$ROOT/agent" && env -i PATH="$PATH" HOME="$HOME" "${agent_env[@]}" node dist/main.js) > "$out/logs/agent.log" 2>&1 &
pids+=($!)

log "starting the backend on :$SERVER_PORT"
(cd "$ROOT/server" && env -i PATH="$PATH" HOME="$HOME" NODE_ENV=e2e PORT="$SERVER_PORT" FOCUS_ENV=e2e \
  FOCUS_DATA_DIR="$work/threads" AGENT_URL="http://localhost:$AGENT_PORT" TZ="$TIMEZONE" \
  ALLOWED_GOOGLE_EMAILS="$email" "${firebase_env[@]}" node dist/main.js) > "$out/logs/server.log" 2>&1 &
pids+=($!)

log "serving the web app on :$WEB_PORT"
python3 -m http.server "$WEB_PORT" --bind 127.0.0.1 --directory "$ROOT/app/build/web" > "$out/logs/web.log" 2>&1 &
pids+=($!)

wait_for "http://localhost:$SERVER_PORT/health" server
wait_for "http://localhost:$WEB_PORT/" web
curl -fsS "http://localhost:$SERVER_PORT/health" > "$out/health.json"

if [ "${E2E_RECORD:-0}" = 1 ]; then
  if [ -n "${DISPLAY:-}" ] && command -v ffmpeg > /dev/null; then
    size="$(xdpyinfo 2> /dev/null | awk '/dimensions:/ {print $2}')"
    log "recording display $DISPLAY (${size:-1280x800})"
    ffmpeg -loglevel error -y -f x11grab -video_size "${size:-1280x800}" -framerate 15 -i "$DISPLAY" \
      -pix_fmt yuv420p "$out/video.mp4" > "$out/logs/ffmpeg.log" 2>&1 &
    recorder=$!
  else
    log "not recording: needs DISPLAY and ffmpeg (run under xvfb-run on Linux)"
  fi
fi

targets=("$@")
[ ${#targets[@]} -gt 0 ] || targets=("$E2E_DIR/maestro")

status=0
TZ="$TIMEZONE" maestro test --platform web \
  --format junit --output "$out/report.xml" --test-output-dir "$out" \
  -e APP_URL="http://localhost:$WEB_PORT" \
  --exclude-tags calendar "${targets[@]}" || status=$?

echo "$status" > "$out/exit-code"
log "done with status $status. Artifacts: $out"
exit "$status"
