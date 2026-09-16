#!/usr/bin/env bash
set -euo pipefail

# deploy-web.sh
#
# Build the Flutter web app and deploy it to the Raspberry Pi's web root.
#
# Usage:
#   scripts/deploy-web.sh <pi-host>
#
# Example:
#   scripts/deploy-web.sh pi@192.168.1.42
#
# Requirements:
#   - Flutter SDK installed locally.
#   - ssh and rsync available locally.
#   - app/env/production.json exists with GOOGLE_SIGN_IN_CLIENT_ID and PROJECT_ID.
#   - The Pi already has /opt/focus/web created and the focus-web container is
#     running (started by the backend deploy script).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PI_HOST="${1:-}"
if [ -z "$PI_HOST" ]; then
  echo "Error: Pi host is required."
  echo "Usage: scripts/deploy-web.sh <pi-host>"
  echo "Example: scripts/deploy-web.sh pi@192.168.1.42"
  exit 1
fi

ENV_FILE="$ROOT_DIR/env/production.json"
if [ ! -f "$ENV_FILE" ]; then
  echo "Error: production env file not found at $ENV_FILE"
  echo "Copy env/production.example.json to env/production.json and fill in your values."
  exit 1
fi

WEB_ENV_FILE="$(mktemp /tmp/focus-web-env.XXXXXX.json)"
trap 'rm -f "$WEB_ENV_FILE"' EXIT

if command -v jq >/dev/null 2>&1; then
  jq '.API_BASE_URL = "/api/" | .FLAVOR = "production"' "$ENV_FILE" > "$WEB_ENV_FILE"
elif command -v python3 >/dev/null 2>&1; then
  python3 -c "
import json
with open('$ENV_FILE') as f:
    data = json.load(f)
data['API_BASE_URL'] = '/api/'
data['FLAVOR'] = 'production'
with open('$WEB_ENV_FILE', 'w') as f:
    json.dump(data, f)
"
else
  echo "Error: jq or python3 is required to generate the web env file."
  exit 1
fi

cd "$ROOT_DIR"

echo "Building Flutter web app for production..."
flutter build web \
  --release \
  --dart-define-from-file "$WEB_ENV_FILE"

echo ""
echo "Deploying to Pi ($PI_HOST)..."
rsync -avz --delete "$ROOT_DIR/build/web/" "$PI_HOST:/opt/focus/web/"

echo ""
echo "Reloading nginx on the Pi..."
ssh "$PI_HOST" "docker exec focus-web nginx -s reload 2>/dev/null || echo 'Container not running — start it with the backend deploy script.'"

echo ""
echo "Web deployment complete."
echo "Visit http://$(echo "$PI_HOST" | sed 's/^.*@//')"
