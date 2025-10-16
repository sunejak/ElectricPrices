#!/bin/bash
#
if [ -z "$1" ]; then
  echo "Provide a security token, a date, and an area in Norway or Finland, and netcosthigh, and netcostlow"
  exit 1
fi
if [ -z "$2" ]; then
  echo "Provide a valid date"
  exit 1
fi
if [ -z "$3" ]; then
  echo "Provide an area in Norway or Finland"
  exit 1
fi
areaInput=$3
#
inDate=$(date -I --date="$2")
if [ $? -ne 0 ]; then
  echo echo "{\"date\": \"$inDate\",\"error\": \"Not a valid date: $2\"}"
  exit 1
fi

today=$(echo "$inDate" | tr -d '-')

if [ -z "$4" ]; then
  echo "Provide net cost high in your area"
  exit 1
fi
netcosthigh=$4
if [ -z "$5" ]; then
  echo "Provide net cost low in your area"
  exit 1
fi
netcostlow=$5
#
# pick a random number between 2 and 20
#
# delay=$(shuf -i 3-20 -n 1)
# get some sleep for the number of minutes, not to overload the server.
# sleep ${delay}m
#
# Gives day-ahead prices
#
dType=A44
#
case $areaInput in
Oslo | oslo)
  area="10YNO-1--------2"
  ;;
Kristiansand | kristiansand)
  area="10YNO-2--------T"
  ;;
Trondheim | trondheim)
  area="10YNO-3--------J"
  ;;
Tromsø | tromsø)
  area="10YNO-4--------9"
  ;;
Bergen | bergen)
  area="10Y1001A1001A48H"
  ;;
Finland | finland)
  area="10YFI-1--------U"
  ;;
*)
  echo echo "{\"date\": \"$inDate\",\"error\": \"Unknown area ${areaInput}\"}"
  exit 1
  ;;
esac

inD=$area
outD=$area
pStart=${today}0000
pEnd=${today}2300
secToken=$1
url=https://web-api.tp.entsoe.eu/api
#
# get the data, response is in XML format
#
url2use="$url?documentType=$dType&in_Domain=$inD&out_Domain=$outD&periodStart=$pStart&periodEnd=$pEnd&securityToken=xxxx";
resultUrl="$url?documentType=$dType&in_Domain=$inD&out_Domain=$outD&periodStart=$pStart&periodEnd=$pEnd&securityToken=$secToken"
xmlResponse=$(curl -s -w " <httpCode>%{http_code}</httpCode>" "$resultUrl")
#
echo $xmlResponse > Response.xml
#
# did curl work?
#
if [ $? -ne 0 ]; then
  echo "{\"date\": \"$inDate\",\"error\": \"Could not access URL at ${url2use}\"}"
  exit 1
fi
#
# what is the HTTP response?
#
httpCode=$(echo "${xmlResponse}" | tr ' ' '\n' | grep "<httpCode>")
#
# check if it is good
#
if [[ $httpCode != "<httpCode>200</httpCode>" ]]; then
  echo "{\"date\": \"$inDate\",\"error\": \"Maintenance mode? $httpCode\" }"
  echo $xmlResponse >> Failed.xml
  exit 1
fi
#
# check if there is a code inside the response (it should not)
#
code=$(echo "$xmlResponse" | tr ' ' '\n' | grep "<code>")

if [ -n "$code" ]; then
  echo "{\"date\": \"$inDate\",\"error\": \"Fetching data from $url failed with: $code\"}";
  exit 1
fi
#
# convert the XML to a JSON array using xq, first remove the httpCode
#
jsonResponse=$(echo "$xmlResponse" | sed "s#<httpCode>200</httpCode>##g" | xq )

echo ${jsonResponse} > data.json

echo "{"
echo "\"date\"": "\"$inDate\""
echo ",\"area\"": "\"$areaInput\""
#
# check how much response you got
#
count=$(echo "$jsonResponse" | jq '.Publication_MarketDocument.TimeSeries.Period | length' )
#
echo $count
count15min=$(echo "$jsonResponse" | jq '.Publication_MarketDocument.TimeSeries.Period.Point | length' )
#
echo $count15min
# echo $jsonResponse > tmp.json
#
# if the count number is 3, then there is only one day in the response (tomorrow)
  #
  # get currency (EUR) in currency_Unit.area
  #
  currency=$(echo "$jsonResponse" | jq .Publication_MarketDocument.TimeSeries | tr -d '.' | jq -r .currency_Unitname)
  #
  # get units (MWH) in .price_Measure_Unit.area
  #
  unit=$(echo "$jsonResponse" | jq .Publication_MarketDocument.TimeSeries | tr -d '.' | jq -r .price_Measure_Unitname)
  #
echo ",\"units\": \"$currency/$unit\""

localArray=()
priceArray=()

exit 0

for i in {0..23}; do
  # get the prices for each hour
  if((count == 3)); then
    price=$(echo "$jsonResponse" | jq .Publication_MarketDocument.TimeSeries.Period.Point[$i] | sed "s/.amount/Amount/" | jq -r .priceAmount)
  else
    price=$(echo "$jsonResponse" | jq .Publication_MarketDocument.TimeSeries.Period[0].Point[$i] | sed "s/.amount/Amount/" | jq -r .priceAmount)
  fi
# differentiate on time (06-22) and (22-06), price needs to be in Euro cents.
# netcosthigh=(0.4030/11.7345)
# netcostlow=(0.3068/11.7345)

  if(( $i >= 6 && $i < 22 )); then
  # bc does not give you trailing zeroes, so a small fix for small negative numbers 
        price=$(echo "scale=2; ($price + $netcosthigh)*100.00/100.00" | bc -l | sed "s/-\./-0./");
      else
        price=$(echo "scale=2; ($price + $netcostlow)*100.00/100.00" | bc -l | sed "s/-\./-0./");
  fi
  priceArray+=("$(echo "${price}")")
  # create a second array with the hour as well
  localArray+=("$(echo "${price}":$i)")
done
# sort the hours expensive first
readarray -t sortedArray < <(printf "%s\n" "${localArray[@]}" | sort -nr | cut -d':' -f2)
# bc results need to be adjusted for small positive numbers
echo ",\"price\": [$(echo "${priceArray[@]}" | tr ' ' ',' | sed "s/,\./,0./g")]"
echo ",\"sortedHour\": [$(echo "${sortedArray[@]}" | tr ' ' ',')]"
echo "}"
