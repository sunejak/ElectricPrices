#!/bin/bash
#
if [ -z "$1" ]; then
  echo "Provide a security token, a date, and an area in Norway or Finland"
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
name=$3
#
inDate=$(date -I --date="$2")
if [ $? -ne 0 ]; then
  echo echo "{\"date\": \"$inDate\",\"error\": \"Not a valid date: $2\"}"
  exit 1
fi

today=$(echo "$inDate" | tr -d '-')
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
case $name in
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
  echo echo "{\"date\": \"$inDate\",\"error\": \"Unknown area ${name}\"}"
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

echo "{"
echo "\"date\"": "\"$inDate\""
echo ",\"area\"": "\"$name\""
#
# check how much response you got
#
count=$(echo "$jsonResponse" | jq '.Publication_MarketDocument.TimeSeries | length' )
#
# if the number is 8, then there is only one day in the response
if((count == 8)); then
  #
  # get currency (EUR) in currency_Unit.name
  #
  currency=$(echo "$jsonResponse" | jq .Publication_MarketDocument.TimeSeries | tr -d '.' | jq -r .currency_Unitname)
  #
  # get units (MWH) in .price_Measure_Unit.name
  #
  unit=$(echo "$jsonResponse" | jq .Publication_MarketDocument.TimeSeries | tr -d '.' | jq -r .price_Measure_Unitname)
  #
else
  currency=$(echo "$jsonResponse" | jq .Publication_MarketDocument.TimeSeries[0] | tr -d '.' | jq -r .currency_Unitname)
  #
  # get units (MWH) in .price_Measure_Unit.name
  #
  unit=$(echo "$jsonResponse" | jq .Publication_MarketDocument.TimeSeries[0] | tr -d '.' | jq -r .price_Measure_Unitname)
fi
echo ",\"units\": \"$currency/$unit\""

localArray=()
priceArray=()

for i in {0..23}; do
  # get the prices for each hour
  if((count == 8)); then
    price=$(echo "$jsonResponse" | jq .Publication_MarketDocument.TimeSeries.Period.Point[$i] | sed "s/.amount/Amount/" | jq -r .priceAmount)
  else
    price=$(echo "$jsonResponse" | jq .Publication_MarketDocument.TimeSeries[0].Period.Point[$i] | sed "s/.amount/Amount/" | jq -r .priceAmount)
  fi
# differentiate on time (06-22) and (22-06), price needs to be in Euro cents.
netcosthigh=(0.4030/11.7345)
netcostlow=(0.3068/11.7345)

  if(( $i >= 6 && $i < 22 )); then
        price=$(echo "scale=2; ($price + $netcosthigh)*100.00/100.00" | bc -l );
      else
        price=$(echo "scale=2; ($price + $netcostlow)*100.00/100.00" | bc -l );
  fi
  priceArray+=("$(echo "${price}")")
  # create a second array with the hour as well
  localArray+=("$(echo "${price}":$i)")
done
# sort the hours expensive first
readarray -t sortedArray < <(printf "%s\n" "${localArray[@]}" | sort -nr | cut -d':' -f2)

echo ",\"price\": [$(echo "${priceArray[@]}" | tr ' ' ',')]"
echo ",\"sortedHour\": [$(echo "${sortedArray[@]}" | tr ' ' ',')]"
echo "}"
