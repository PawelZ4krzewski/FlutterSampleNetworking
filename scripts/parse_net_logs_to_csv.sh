#!/usr/bin/env sh
# Parse NET_GET_MS lines from logs and append to metrics/results_YYYYMMDD.csv
# Usage: parse_net_logs_to_csv.sh <platform> <scenario> <logfile>
set -eu
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <platform> <scenario> <logfile>" >&2
  exit 2
fi
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
METRICS_DIR="$ROOT_DIR/metrics"
mkdir -p "$METRICS_DIR"
PLATFORM="$1"
SCENARIO="$2"
LOGFILE="$3"
DATE=$(date +%Y%m%d)
OUT_CSV="$METRICS_DIR/results_${DATE}.csv"
[ -f "$OUT_CSV" ] || echo "tool,platform,scenario,t_start_ms,t_end_ms,duration_ms,success,status,notes" > "$OUT_CSV"

# Grep lines like: [App] NET_GET_MS: 123
awk -v tool="flutter" -v platform="$PLATFORM" -v scenario="$SCENARIO" '
  /NET_GET_MS:/ {
    # Use current epoch ms for start/end placeholders; duration from log
    cmd="date +%s%3N"; cmd | getline now; close(cmd);
    split($0, a, ": "); dur=a[length(a)];
    gsub(/[^0-9]/, "", dur);
    t_start=now; t_end=now; success="true"; status="200"; notes="";
    print tool "," platform "," scenario "," t_start "," t_end "," dur "," success "," status "," notes;
  }
' "$LOGFILE" >> "$OUT_CSV"

echo "Appended NET_GET_MS entries to $OUT_CSV"
