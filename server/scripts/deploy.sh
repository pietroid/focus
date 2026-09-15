#!/usr/bin/env bash
set -euo pipefail

# deploy.sh
#
# Deploy the NestJS backend to a Raspberry Pi running Docker.
#
# Usage:
#   scripts/deploy.sh prod --host pi.local
#   scripts/deploy.sh prod --host 192.168.1.100 --user pi
#
# The service account JSON key must already be present on the Pi at the path
# configured in docker-compose.yml (default: /opt/focus/secrets/focus-backend-prod.json).
# The key is NEVER copied from this repo; keep it outside version control.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ENVIRONMENT="${1:-}"
shift || true

PI_HOST=""
PI_USER="pi"
PI_DIR="/opt/focus"

# Parse remaining args
while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      PI_HOST="$2"
      shift 2
      ;;
    --user)
      PI_USER="$2"
      shift 2
      ;;
    --pi-dir)
      PI_DIR="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 <prod> --host <pi-host> [--user <pi-user>] [--pi-dir <dir>]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [ -z "$ENVIRONMENT" ] || [ "$ENVIRONMENT" != "prod" ]; then
  echo "Only production deployments to the Pi are supported."
  echo "Usage: $0 prod --host <pi-host>"
  exit 1
fi

if [ -z "$PI_HOST" ]; then
  echo "Error: --host is required."
  echo "Usage: $0 prod --host <pi-host>"
  exit 1
fi

ENV_FILE="$ROOT_DIR/.env.production"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
IMAGE_NAME="focus-backend:latest"
IMAGE_TAR="focus-backend.tar"

echo "Deploying Focus backend to Raspberry Pi"
echo "  Host: $PI_HOST"
echo "  User: $PI_USER"
echo "  Pi dir: $PI_DIR"
echo ""

cd "$ROOT_DIR"

echo "Building Docker image for linux/arm64..."
if ! docker buildx build --platform linux/arm64 -t "$IMAGE_NAME" --load .; then
  echo ""
  echo "Local cross-platform build failed. You can either:"
  echo "  1. Install Docker Desktop or docker-buildx, or"
  echo "  2. Build directly on the Pi: ssh $PI_USER@$PI_HOST 'cd $PI_DIR && docker compose build'"
  exit 1
fi

echo "Saving image to $IMAGE_TAR..."
docker save "$IMAGE_NAME" -o "$IMAGE_TAR"

echo "Creating remote directory..."
ssh "${PI_USER}@${PI_HOST}" "mkdir -p ${PI_DIR}"

echo "Copying image, compose file and environment..."
scp "$IMAGE_TAR" "$COMPOSE_FILE" "$ENV_FILE" "${PI_USER}@${PI_HOST}:${PI_DIR}/"

echo "Loading image and starting container on the Pi..."
ssh "${PI_USER}@${PI_HOST}" "cd ${PI_DIR} && docker load -i ${IMAGE_TAR} && docker compose up -d"

echo ""
echo "Deployment complete."
echo ""
echo "Make sure the service account key is present on the Pi at:"
echo "  /opt/focus/secrets/focus-backend-prod.json"
echo ""
echo "Update app/env/production.json with the Pi URL once the hostname is known."
