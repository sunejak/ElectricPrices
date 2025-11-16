#!/bin/bash

if [ "${1:-}" = "" ]; then
  echo "Usage: $0 input.json"
  exit 1
fi

localArray=()
# read the input JSON
inputJSON=$(jq -c . $1)

inDate=$(echo "$inputJSON" | jq -r .date)
areaInput=$(echo "$inputJSON" | jq -r .area)
unitsInput=$(echo "$inputJSON" | jq -r .units)

echo "{"
echo "\"date\"": "\"$inDate\""
echo ",\"area\"": "\"$areaInput\""
echo ",\"units\": \"$unitsInput\""

# it should have 96 values, so chunk them as four, and calculate the average.
for i in {0..95}; do
  if [[ $((i % 4)) -eq 0 ]];
  then
    hour=$(( i/4 ))
    var=$(echo "$inputJSON" | jq -c .price15Minutes[$i:$((i+4))] | tr ',' '+' | tr -d '[' | tr -d ']')
    calc=$(echo "scale=2; ($var)*100.00/400.00" | bc -l | sed "s/-\./-0./");
    localArray+=("$(echo $hour $calc)")
  fi
done



readarray -t sortedArray < <(printf "%s\n" "${localArray[@]}" | sort -nrk2 | cut -d' ' -f1)
readarray -t priceArray < <(printf "%s\n" "${localArray[@]}" | cut -d' ' -f2)

echo ",\"price\": [$(echo "${priceArray[@]}" | tr ' ' ',' | sed "s/,\./,0./g")]"
echo ",\"sortedHour\": [$(echo "${sortedArray[@]}" | tr ' ' ',')]"
echo "}"

exit 0
