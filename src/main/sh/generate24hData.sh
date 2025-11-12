#!/bin/bash

if [ "${1:-}" = "" ]; then
  echo "Usage: $0 input.json"
  exit 1
fi

if [ -z "$2" ]; then
  echo "Provide a valid offset"
  exit 1
fi

if [ -z "$3" ]; then
  echo "Provide a area"
  exit 1
fi

inputfile=$1
declare -i hour=$2
area=$3

echo "{"

inDate=$(jq -r .TimeSeries[1].end  ${inputfile} | cut -d 'T' -f1)
currency=$(jq -r .TimeSeries[1].currency  ${inputfile})
unit=$(jq -r .TimeSeries[1].price  ${inputfile})

echo "\"date\"": "\"$inDate\""
echo ",\"area\"": "\"$area\""

echo ",\"units\": \"$currency/$unit\""

# {"id":"2","start":"2025-10-31T23:00Z","end":"2025-11-01T23:00Z","currency":"EUR","price":"MWH","curve":"A03","points":[{"position":1

declare -A localArray=()
declare -A priceArray=()

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
#    hour=0

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
            avg=$(echo "scale=2; $sum / 4" | bc -l)
            localArray+=$(printf "%s %s Hour %s \n" "$avg" "$id" "$hour")
            sum=0
            count=0
            hour+=1
        fi
    done
echo ${localArray[@]}
done


echo Final result: ${localArray[@]}
