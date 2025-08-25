#!/usr/bin/env sh
set -eu

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
METRICS_DIR="$ROOT_DIR/metrics"
STAT_SH="$ROOT_DIR/scripts/_stat_size.sh"
mkdir -p "$METRICS_DIR"

cd "$ROOT_DIR"

flutter clean
flutter pub get
flutter build ipa --no-codesign || true

# For no-codesign, record .app bundle size if .ipa isn't produced
APP_PATH=$(ls -1 "$ROOT_DIR"/build/ios/archive/*.xcarchive/Products/Applications/*.app 2>/dev/null | head -n1 || true)
if [ -n "$APP_PATH" ] && [ -d "$APP_PATH" ]; then
  # du -sk gives KB; convert to bytes
  du -sk "$APP_PATH" | awk '{print $1*1024}' > "$METRICS_DIR/build_size_ipa.txt"
  echo "iOS app bundle size bytes written to $METRICS_DIR/build_size_ipa.txt"
else
  echo "0" > "$METRICS_DIR/build_size_ipa.txt"
  echo "iOS app bundle not found"
fi
