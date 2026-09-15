#!/usr/bin/env bash
set -euo pipefail

# deploy-local.sh
#
# One-command local deployment of the Focus backend to the Raspberry Pi.
# This script deploys whatever is currently checked out in the local repo
# (intended to be run from the main branch).
#
# Usage:
#   ./deploy-local.sh
#   ./deploy-local.sh --no-pull

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
PI_HOST="focus.local"
PI_USER="focus"
PULL=true

while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-pull)
      PULL=false
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--no-pull]"
      echo ""
      echo "Options:"
      echo "  --no-pull   Skip pulling latest changes from origin/main"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

cd "$ROOT_DIR"

echo "Deploying Focus backend to Raspberry Pi"
echo "  Host: $PI_HOST"
echo "  User: $PI_USER"
echo ""

CURRENT_BRANCH="$(git branch --show-current)"
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "Error: you must be on the 'main' branch to deploy (currently on '$CURRENT_BRANCH')."
  echo "Switch with: git switch main"
  exit 1
fi

if [ "$PULL" = true ]; then
  echo "Pulling latest changes from origin/main..."
  git pull origin main
else
  echo "Skipping git pull (--no-pull)."
fi

echo ""
echo "Starting Docker deployment..."
cd "$ROOT_DIR/server"
npm run deploy:prod -- --host "$PI_HOST" --user "$PI_USER"
