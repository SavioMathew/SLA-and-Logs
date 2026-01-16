#!/usr/bin/env bash
set -euo pipefail

############################
# REQUIRED ENV VARIABLES
############################

: "${LOKI_URL:?LOKI_URL not set}"
: "${LOKI_USER:?LOKI_USER not set}"
: "${LOKI_TOKEN:?LOKI_TOKEN not set}"
: "${JOB_NAME:?JOB_NAME not set}"

############################
# OPTIONAL CONFIG
############################

OVERLAP_SECONDS="${OVERLAP_SECONDS:-300}"          # 5 minutes
STATE_FILE="${STATE_FILE:-.last_fetched_ns}"
LOG_DIR="${LOG_DIR:-logs}"

RAW_LOG_FILE="${LOG_DIR}/raw_logs"
READABLE_LOG_FILE="${LOG_DIR}/$(date +%F)_${JOB_NAME// /_}.log"

mkdir -p "$LOG_DIR"
touch "$RAW_LOG_FILE"
touch "$READABLE_LOG_FILE"

############################
# TIME WINDOW CALCULATION
############################

if [[ -f "$STATE_FILE" ]]; then
    LAST_END_NS=$(<"$STATE_FILE")
    START_NS=$(( LAST_END_NS - OVERLAP_SECONDS * 1000000000 ))
else
    START_NS=$(date -u -d "1 hour ago" +%s)000000000
fi

END_NS=$(date -u +%s)000000000

echo "Fetching logs for job: $JOB_NAME"
echo "From: $(date -d "@$((START_NS/1000000000))")"
echo "To  : $(date -d "@$((END_NS/1000000000))")"

############################
# FETCH RAW LOGS (DEDUP)
############################

curl -s -u "${LOKI_USER}:${LOKI_TOKEN}" -G "${LOKI_URL}" \
  --data-urlencode "query={job=\"${JOB_NAME}\"} |= \"\"" \
  --data-urlencode "start=${START_NS}" \
  --data-urlencode "end=${END_NS}" \
  --data-urlencode "limit=5000" |
jq -r '
  .data.result[]?.values[]?
  | "\(. [0]) \(. [1] | gsub("\n$"; ""))"
' |
awk '!seen[$0]++' >> "$RAW_LOG_FILE"

############################
# UPDATE STATE
############################

echo "$END_NS" > "$STATE_FILE"

############################
# GENERATE READABLE LOGS
# (FROM RAW LOGS ONLY)
############################

awk '
{
    ts_ns=$1
    $1=""

    ts_sec=int(ts_ns/1000000000)
    cmd="date -d @" ts_sec " \"+%Y-%m-%d %H:%M:%S\""
    cmd | getline human_time
    close(cmd)

    printf "[%s] %s\n", human_time, substr($0,2)
}
' "$RAW_LOG_FILE" | awk '!seen[$0]++' > "$READABLE_LOG_FILE"

############################
# DONE
############################

echo "Raw logs      : $RAW_LOG_FILE"
echo "Readable logs : $READABLE_LOG_FILE"

