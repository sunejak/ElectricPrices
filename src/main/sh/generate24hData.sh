#!/bin/bash

if [ "${1:-}" = "" ]; then
  echo "Usage: $0 input.json"
  exit 1
fi

inputfile=$1

jq -c '.TimeSeries[]' ${inputfile} | while read -r ts; do
    id=$(jq -r '.id' <<< "$ts")

    declare -A price
    price=()

    # Load position → price pairs (use zero-based index)
    while IFS=$'\t' read -r pos pr; do
        idx=$((pos - 1))
        price[$idx]=$pr
    done < <(jq -r '.points[] | "\(.position)\t\(.price)"' <<< "$ts")

    echo "=== Hourly averages for TimeSeries: $id ==="

    last_price="0"
    sum=0
    count=0
    hour=0

    for (( j = 0; j < 96; j++ )); do
        # If there’s a valid price for this index, update last known
        if [[ -n "${price[$j]}" ]]; then
            last_price="${price[$j]}"
        fi

        # If still empty, fallback to 0
        val="${price[$j]:-$last_price}"
        if [[ -z "$val" ]]; then
            val=0
        fi

        # Add to sum
        sum=$(echo "$sum + $val" | bc -l)
        ((count++))

        # Every 4 values = one hour
        if (( count == 4 )); then
            avg=$(echo "scale=3; $sum / 4" | bc -l)
            printf "Hour %02d: %s\n" "$hour" "$avg"
            sum=0
            count=0
            ((hour++))
        fi
    done

    echo
done
