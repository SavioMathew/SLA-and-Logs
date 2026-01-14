#!/usr/bin/env bash
set -euo pipefail

##########################
# REQUIRED ENV VARIABLES
##########################
: "${GRAFANA_USER:?GRAFANA_USER not set}"
: "${GRAFANA_TOKEN:?GRAFANA_TOKEN not set}"
: "${GRAFANA_URL:?GRAFANA_URL not set}"

##########################
# CONFIG
##########################
JOB="APIs Testing"
LOOKBACK_SECONDS=3600          # last 1 hour
RAW_FILE="raw_logs.json"
READABLE_FILE="readable_logs.txt"

echo "Fetching logs from Loki..."

# Calculate timestamps in nanoseconds
START_TIME=$(( $(date +%s) - LOOKBACK_SECONDS ))000000000
END_TIME=$(date +%s)000000000

# Fetch logs
curl -s -u "$GRAFANA_USER:$GRAFANA_TOKEN" \
     -G "$GRAFANA_URL" \
     --data-urlencode "query={job=\"$JOB\"}" \
     --data-urlencode "start=$START_TIME" \
     --data-urlencode "end=$END_TIME" \
     > "$RAW_FILE"

echo "Raw logs saved to $RAW_FILE"

# Extract readable logs
if jq -e '.data.result | length > 0' "$RAW_FILE" > /dev/null; then
    jq -r '
      .data.result[] 
      | .values[] 
      | .[1]   # extract the log message text
    ' "$RAW_FILE" > "$READABLE_FILE"
    echo "Readable logs saved to $READABLE_FILE"
else
    echo "No logs found."
    > "$READABLE_FILE"
fi

echo "Done ✅"

