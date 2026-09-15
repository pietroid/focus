#!/usr/bin/env bash
set -euo pipefail

# update_firebase_config.sh
#
# Re-downloads/regenerates Firebase configuration files for the
# production flavor only. Development is not currently configured.
#
# Project ID is read from the committed env file:
#   - app/env/production.json  -> PROD_PROJECT_ID
#
# If the env file does not contain a PROJECT_ID, the default is used:
#   - Production: focus-production

# Navigate to the project root (where this script lives)
cd "$(dirname "$0")"

read_json_field() {
  local file="$1"
  local key="$2"
  local default="$3"

  if [ -f "$file" ] && command -v jq >/dev/null 2>&1; then
    jq -r ".${key} // empty" "$file" || true
  elif [ -f "$file" ] && command -v python3 >/dev/null 2>&1; then
    python3 -c "import json; print(json.load(open('$file')).get('$key', ''))" || true
  else
    echo ""
  fi
}

PROD_PROJECT_ID="$(read_json_field env/production.json PROJECT_ID focus-production)"
# DEV_PROJECT_ID="$(read_json_field env/development.json PROJECT_ID focus-development)"

# Fall back to defaults if the env files did not contain the values
PROD_PROJECT_ID="${PROD_PROJECT_ID:-focus-production}"
# DEV_PROJECT_ID="${DEV_PROJECT_ID:-focus-development}"

echo "Updating Firebase configs..."
echo "  Production project: $PROD_PROJECT_ID"
# echo "  Development project: $DEV_PROJECT_ID"
echo ""

# Make sure flavor directories exist
mkdir -p android/app/src/production
# mkdir -p android/app/src/development

# Remove any stale default-generated file so we only keep the per-flavor files
rm -f lib/firebase_options.dart
rm -f android/app/google-services.json

# echo "=> Configuring production flavor..."
flutterfire configure \
  --project="$PROD_PROJECT_ID" \
  --out=lib/firebase_options_production.dart \
  --platforms=android,ios,web \
  --ios-bundle-id=com.pietroid.focus \
  --android-package-name=com.pietroid.focus \
  --overwrite-firebase-options \
  --yes

# Move the generated Android config into the production flavor
mv android/app/google-services.json android/app/src/production/google-services.json

# Development flavor is not currently configured. When it is, restore the
# flutterfire configure step for the dev project and the plist swap below.

# Keep a backup of the production iOS plist before we overwrite it with dev
# cp ios/Runner/GoogleService-Info.plist ios/Runner/GoogleService-Info.plist.prod

# echo ""
# echo "=> Configuring development flavor..."
# flutterfire configure \
#   --project="$DEV_PROJECT_ID" \
#   --out=lib/firebase_options_development.dart \
#   --platforms=android,ios,web \
#   --ios-bundle-id=com.pietroid.focus.dev \
#   --android-package-name=com.pietroid.focus.dev \
#   --overwrite-firebase-options \
#   --yes

# Move the generated Android config into the development flavor
# mv android/app/google-services.json android/app/src/development/google-services.json

# Rename the dev plist and restore the production plist
# mv ios/Runner/GoogleService-Info.plist ios/Runner/GoogleService-Info-Development.plist
# mv ios/Runner/GoogleService-Info.plist.prod ios/Runner/GoogleService-Info.plist

echo ""
echo "Firebase config update complete."
echo ""
echo "Generated files:"
echo "  lib/firebase_options_production.dart"
# echo "  lib/firebase_options_development.dart"
echo "  android/app/src/production/google-services.json"
# echo "  android/app/src/development/google-services.json"
echo "  ios/Runner/GoogleService-Info.plist"
# echo "  ios/Runner/GoogleService-Info-Development.plist"
