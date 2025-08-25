#!/usr/bin/env sh
set -eu

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
METRICS_DIR="$ROOT_DIR/metrics"
STAT_SH="$ROOT_DIR/scripts/_stat_size.sh"
mkdir -p "$METRICS_DIR"

cd "$ROOT_DIR"

flutter clean
flutter pub get

# APK
flutter build apk --release
APK_PATH="$ROOT_DIR/build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
  "$STAT_SH" "$APK_PATH" > "$METRICS_DIR/build_size_apk.txt"
  echo "APK size bytes written to $METRICS_DIR/build_size_apk.txt"
else
  echo "0" > "$METRICS_DIR/build_size_apk.txt"
  echo "APK not found at $APK_PATH"
fi

# AAB
flutter build appbundle --release || true
AAB_PATH="$ROOT_DIR/build/app/outputs/bundle/release/app-release.aab"
if [ -f "$AAB_PATH" ]; then
  "$STAT_SH" "$AAB_PATH" > "$METRICS_DIR/build_size_aab.txt"
  echo "AAB size bytes written to $METRICS_DIR/build_size_aab.txt"
else
  echo "0" > "$METRICS_DIR/build_size_aab.txt"
  echo "AAB not found"
fi
