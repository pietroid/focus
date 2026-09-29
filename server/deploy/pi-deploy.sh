#!/usr/bin/env bash
# pi-deploy.sh
#
# Runs ON the Pi. The deploy workflows pipe it over SSH:
#
#   ssh focus-pi 'bash -s' -- <component> [version] < server/deploy/pi-deploy.sh
#
#   component  backend | agent | web
#   version    the commit the image was built from; checked against /health
#
# backend and agent expect their image archive at /tmp/focus-<component>.tar.gz.
# web expects the static files to be in place already (the workflow rsyncs
# them) and only reloads nginx.
set -euo pipefail

component="${1:?component: backend | agent | web}"
version="${2:-}"
repo_path="${PI_REPO_PATH:-$HOME/focus}"

case "$component" in
  backend) services=(focus-backend focus-web) ;;
  agent) services=(focus-agent) ;;
  web) services=() ;;
  *)
    echo "Unknown component '$component'." >&2
    exit 1
    ;;
esac

echo "Pulling latest repo state in $repo_path..."
git -C "$repo_path" pull --ff-only
cd "$repo_path/server"

if [ "$component" = web ]; then
  echo "Reloading nginx..."
  docker exec focus-web nginx -s reload
  echo "Web deploy complete."
  exit 0
fi

archive="/tmp/focus-$component.tar.gz"
echo "Loading $archive..."
docker load < "$archive"
rm -f "$archive"

echo "Restarting ${services[*]}..."
docker compose up -d "${services[@]}"

if [ "$component" = backend ]; then
  # The new container has to answer, and has to be the build we just shipped.
  echo "Waiting for focus-backend to answer /health..."
  for _ in $(seq 1 30); do
    health="$(docker exec focus-backend wget -qO- http://localhost:3000/health 2>/dev/null || true)"
    if [ -n "$health" ]; then
      echo "$health"
      if [ -n "$version" ] && ! grep -q "\"version\":\"$version\"" <<< "$health"; then
        echo "focus-backend is up but reports another version (wanted $version)." >&2
        exit 1
      fi
      echo "Backend deploy complete."
      exit 0
    fi
    sleep 2
  done
  echo "focus-backend did not answer /health in time." >&2
  docker logs --tail 50 focus-backend >&2 || true
  exit 1
fi

echo "Agent deploy complete."
