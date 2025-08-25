#!/usr/bin/env sh
# Print file size in bytes on macOS and Linux
# Usage: _stat_size.sh <path>
set -eu
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <path>" >&2
  exit 2
fi
p="$1"
if [ ! -e "$p" ]; then
  echo "0"
  exit 0
fi
if stat -f "%z" "$p" >/dev/null 2>&1; then
  stat -f "%z" "$p"
else
  stat -c%s "$p"
fi
