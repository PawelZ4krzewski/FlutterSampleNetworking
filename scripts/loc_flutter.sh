#!/usr/bin/env sh
set -eu

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
METRICS_DIR="$ROOT_DIR/metrics"
mkdir -p "$METRICS_DIR"

OUT_FILE="$METRICS_DIR/loc_flutter.txt"

if command -v cloc >/dev/null 2>&1; then
  cloc \
    --quiet \
    --exclude-dir=build,.dart_tool,ios/Flutter/ephemeral,macos/Flutter/ephemeral,android/.gradle,.git \
    "$ROOT_DIR" > "$OUT_FILE"
else
  echo "cloc not found, using fallback find|wc" > "$OUT_FILE"
  find "$ROOT_DIR" \
    -type d \( -name build -o -name .dart_tool -o -name ephemeral -o -name .git -o -name .gradle \) -prune -o \
    -type f \( -name "*.dart" -o -name "*.kt" -o -name "*.swift" -o -name "*.gradle" -o -name "*.xml" -o -name "*.yaml" \) -print \
    | wc -l >> "$OUT_FILE"
fi

echo "LOC results written to $OUT_FILE"
