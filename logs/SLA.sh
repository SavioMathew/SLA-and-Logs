#!/usr/bin/env bash
set -euo pipefail

: "${LOKI_URL:?LOKI_URL not set}"
: "${LOKI_USER:?LOKI_USER not set}"
: "${LOKI_TOKEN:?LOKI_TOKEN not set}"
: "${JOB_NAME:?JOB_NAME not set}"

FROM=$(date -u -d '3 hours ago' +"%Y-%m-%dT%H:%M:%SZ")
TO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

START_NS=$(date -d "$FROM" +%s)000000000
END_NS=$(date -d "$TO" +%s)000000000

echo "Fetching logs for job: $JOB_NAME from $FROM to $TO..."

RESPONSE=$(curl -s -G "$LOKI_URL" \
  --user "$LOKI_USER:$LOKI_TOKEN" \
  --data-urlencode "query={job=\"$JOB_NAME\"}" \
  --data-urlencode "start=$START_NS" \
  --data-urlencode "end=$END_NS" \
  --data-urlencode "limit=5000")

# Check if response is valid JSON
if ! echo "$RESPONSE" | jq . >/dev/null 2>&1; then
    echo "ERROR: Loki response is not valid JSON. Here’s the raw response:"
    echo "$RESPONSE"
    exit 1
fi

# Safely extract log lines
LOG_LINES=$(echo "$RESPONSE" | jq -r '
  .data.result[]?.values[]? | 
  select(type=="array" and length==2) | .[1]
')

TOTAL=$(echo "$LOG_LINES" | wc -l)
SUCCESS=$(echo "$LOG_LINES" | grep -c 'status 200')

if [[ $TOTAL -eq 0 ]]; then
  SLA=0
else
  SLA=$(echo "scale=2; $SUCCESS/$TOTAL*100" | bc)
fi

echo
echo "SLA REPORT (FROM LOKI LOGS)"
echo "Generated: $(date -u)"
echo "Job: $JOB_NAME"
echo "Time range: $FROM to $TO"
echo "----------------------------------------"
echo "TOTAL REQUESTS: $TOTAL"
echo "SUCCESSFUL:    $SUCCESS"
echo "SLA %:         $SLA%"
echo "----------------------------------------"

