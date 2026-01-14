#!/usr/bin/env bash
set -euo pipefail

##########################
# REQUIRED ENV VARIABLES
##########################
: "${LOKI_URL:?LOKI_URL not set}"
: "${LOKI_USER:?LOKI_USER not set}"
: "${LOKI_TOKEN:?LOKI_TOKEN not set}"

##########################
# CONFIG
##########################
JOB="APIs Testing"
LOOKBACK_SECONDS=300                # 5-min overlap
RAW_LOG_FILE="raw_logs.json"
READABLE_LOG_FILE="readable_logs.txt"

# Time range: last 1 hour + overlap
END_TS=$(date +%s)
START_TS=$((END_TS - 3600 - LOOKBACK_SECONDS))

echo "Fetching logs from Loki..."
echo "Time range: $(date -d "@$START_TS" -u) UTC → $(date -d "@$END_TS" -u) UTC"

# Fetch raw logs
curl -s -u "$LOKI_USER:$LOKI_TOKEN" -G "$LOKI_URL" \
  --data-urlencode "query={job=\"$JOB\"}" \
  --data-urlencode "limit=1000" \
  --data-urlencode "start=$((START_TS*1000000000))" \
  --data-urlencode "end=$((END_TS*1000000000))" \
  > "$RAW_LOG_FILE"

echo "Raw logs saved to $RAW_LOG_FILE"

# Extract readable logs (just combine all log values)
jq -r '.data.result[]?.values[] | .[1]' "$RAW_LOG_FILE" > "$READABLE_LOG_FILE"

echo "Readable logs saved to $READABLE_LOG_FILE"

# Extract actual log timestamps from `time=` field in each line
timestamps=$(grep -oP 'time=\K[0-9TZ:\-]+' "$READABLE_LOG_FILE" | sort)
if [[ -n "$timestamps" ]]; then
    start_time=$(echo "$timestamps" | head -n1)
    end_time=$(echo "$timestamps" | tail -n1)
    echo "Logs fetched from: $start_time to $end_time"
else
    echo "No timestamps found in logs."
fi

echo "Done ✅"

