#!/bin/bash

if [ "${1:-}" = "" ]; then
  echo "Usage: $0 input.json"
  exit 1
fi

if [ -z "$2" ]; then
  echo "Provide a valid offset (24 is no offset)"
  exit 1
fi

if [ -z "$3" ]; then
  echo "Provide a area (Trondheim)"
  exit 1
fi

inputFile=$1
declare -i offset=$2
area=$3

echo "{"

inDate=$(jq -r .TimeSeries[1].end  "${inputFile}" | cut -d 'T' -f1)
currency=$(jq -r .TimeSeries[1].currency  "${inputFile}")
unit=$(jq -r .TimeSeries[1].price  "${inputFile}")

echo "\"date\"": "\"$inDate\""
echo ",\"area\"": "\"$area\""
echo ",\"units\": \"$currency/$unit\""

# {"id":"2","start":"2025-10-31T23:00Z","end":"2025-11-01T23:00Z","currency":"EUR","price":"MWH","curve":"A03","points":[{"position":1

declare -A localArray=()

jsonPrices=$(jq -c '.TimeSeries[0].points + (.TimeSeries[1].points | map(.position += 96))' "${inputFile}")
elements=$(echo "$jsonPrices" | jq '. | length')

# echo $jsonPrices

declare -i ptr=0;

# extract the entries from the JSON input array
while [ $ptr -lt "$elements" ]
  do
  # hour=$(((ptr / 4) - offset))
  position=$(echo "${jsonPrices}" | jq .[$ptr].position)
  # echo $position
  price15min=$(echo "${jsonPrices}" | jq .[$ptr].price)
  # echo $price
  pos=$((position-1))
  localArray[${pos}]="${price15min} ## $((position-(offset*4)-1))"
  ((ptr++))
done

# fix the empty positions in the array, by copying the previous entry. curve=A03
for n in {0..191};
  do
  if [[ -z ${localArray[$n]} ]]; then
    localArray[$n]=${localArray[$((n-1))]}
  fi
    # echo $n ${localArray[$n]}
done

readarray -t priceArray < <(printf "%s\n" "${localArray[@]}"  | grep -v "## -" | sort -nk3 | cut -d' ' -f1)
readarray -t sortedArray < <(printf "%s\n" "${localArray[@]}" | grep -v "## -" | sort -nr | cut -d' ' -f3 | tr -d ':')

echo ",\"price15Minutes\": [$(echo "${priceArray[@]:0:96}" | tr ' ' ',' | sed "s/,\./,0./g")]"
echo ",\"sorted15Minutes\": [$(echo "${sortedArray[@]:0:96}" | tr ' ' ',')]"

echo "}"
exit 0
