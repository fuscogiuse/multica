#!/usr/bin/env bash
# Builds, signs and installs Calm Tasks on a connected iPhone (cable or network).
# Usage: TEAM=<team id> ./build-device.sh [device-udid] [bundle-prefix]
# Free Personal Team: bundle ids must be unique, so pass your own prefix (default it.calmtasks.$USER).
set -euo pipefail
cd "$(dirname "$0")"
: "${TEAM:?Set TEAM to your Apple development team id (Xcode > Settings > Accounts)}"
DEVICE="${1:-$(xcrun devicectl list devices 2>/dev/null | awk '/iPhone/ && /(connected|available)/ {for(i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-/) {print $i; exit}}')}"
: "${DEVICE:?No iPhone found. Unlock it, join the same Wi-Fi as this Mac, and check Xcode > Window > Devices.}"
PREFIX="${2:-it.calmtasks.$USER}"
xcodegen generate >/dev/null
xcodebuild -project CalmTasks.xcodeproj -scheme CalmTasks -destination "platform=iOS,id=$DEVICE" \
  -derivedDataPath build-device -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic CT_BUNDLE_PREFIX="$PREFIX" \
  CURRENT_PROJECT_VERSION="$(git rev-list --count HEAD)" build | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
xcrun devicectl device install app --device "$DEVICE" build-device/Build/Products/Debug-iphoneos/CalmTasks.app
echo "Installed. If the app will not open, trust the developer in Settings > General > VPN & Device Management."
