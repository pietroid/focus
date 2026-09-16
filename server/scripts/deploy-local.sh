#!/usr/bin/env bash
set -euo pipefail

# deploy-local.sh
#
# Deploy the NestJS backend locally on the Raspberry Pi.
#
# Usage:
#   scripts/deploy-local.sh
#
# Must be run from inside the Raspberry Pi where the repo is cloned.
# It pulls the latest code, builds the Docker image natively, and starts
# the container with docker compose.
#
# The service account JSON key must already be present on the Pi at:
#   /opt/focus/secrets/focus-backend-prod.json
# The key is NEVER committed; keep it outside version control.
#
# The Flutter web app is served separately by the focus-web (nginx) container.
# Populate /opt/focus/web on the Pi by running app/scripts/deploy-web.sh from
# your development machine.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE="$ROOT_DIR/.env.production"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
IMAGE_NAME="focus-backend:latest"

cd "$ROOT_DIR"

echo "Pulling latest code..."
git pull

echo ""
echo "Ensuring web root exists..."
mkdir -p /opt/focus/web

echo ""
echo "Building Docker image..."
docker build -t "$IMAGE_NAME" .

echo ""
echo "Starting containers with docker compose..."
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d

echo ""
echo "Deployment complete."
echo ""
echo "Make sure the service account key is present on the Pi at:"
echo "  /opt/focus/secrets/focus-backend-prod.json"
