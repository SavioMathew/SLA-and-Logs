#!/usr/bin/env bash
set -euo pipefail

INPUT_FILE="readable_logs.txt"

CITIES=("Mumbai" "Zurich" "Oregon")
APIS=("/health" "/metrics")

echo "SLA Report"
echo "=========="
printf "%-10s %-10s %-10s %-10s %-10s\n" "City" "API" "Success" "Total" "SLA%"

for city in "${CITIES[@]}"; do
    city_success_total=0
    city_total_total=0

    for api in "${APIS[@]}"; do
        # Total lines for city & API
        total=$(grep -E "target=.*${api}" "$INPUT_FILE" | grep "probe=${city}" | wc -l)

        # Extract uptime %, convert to count of successes
        # Assuming log line: "Uptime 100.0%"
        success=0
        while read -r line; do
            uptime=$(echo "$line" | grep -oP 'Uptime\s+\K[0-9]+(\.[0-9]+)?')
            # Calculate success count = uptime% of 1 execution (so for total lines, multiply later)
            success=$(echo "$success + ($uptime/100)" | bc -l)
        done < <(grep -E "target=.*${api}" "$INPUT_FILE" | grep "probe=${city}")

        # Round success to integer
        success=$(printf "%.0f" "$success")

        city_success_total=$((city_success_total + success))
        city_total_total=$((city_total_total + total))

        if [ "$total" -eq 0 ]; then
            sla=0
        else
            sla=$(echo "scale=2; $success/$total*100" | bc)
        fi

        printf "%-10s %-10s %-10s %-10s %-10s\n" "$city" "$api" "$success" "$total" "$sla%"
    done

    # TOTAL per city
    if [ "$city_total_total" -eq 0 ]; then
        city_sla=0
    else
        city_sla=$(echo "scale=2; $city_success_total/$city_total_total*100" | bc)
    fi
    printf "%-10s %-10s %-10s %-10s %-10s\n" "$city" "TOTAL" "$city_success_total" "$city_total_total" "$city_sla%"
done

