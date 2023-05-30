#!/bin/bash
#
if [ -z "$1" ]; then
  echo "Provide a security token, a date, an area in Norway and a plot output file"
  exit 1
fi

if [ -z "$2" ]; then
  echo "Provide a date"
  exit 1
fi

if [ -z "$3" ]; then
  echo "Provide an area in Norway"
  exit 1
fi
plotfile=$4
#
inDate=$(date -I --date="$2")
if [ $? -ne 0 ]; then
  exit 1
fi

today=$(echo "$inDate" | tr -d '-')
#
# pick a random number between 2 and 20
#
# delay=$(shuf -i 3-20 -n 1)
#
# get some sleep for the number of minutes, not to overload the server.
#
# sleep ${delay}m
#
# Gives day-ahead prices
#
dType=A44
#
case $3 in
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
*)
  echo -n "unknown Norwegian area"
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
resultUrl="$url?documentType=$dType&in_Domain=$inD&out_Domain=$outD&periodStart=$pStart&periodEnd=$pEnd&securityToken=$secToken"

xmlResponse=$(curl -s -w " <httpCode>%{http_code}</httpCode>" "$resultUrl")
#
# did curl work?
#
if [ $? -ne 0 ]; then
  echo "{\"message\": \"Could not access URL at ${resultUrl}\"}"
  exit 1
fi
#
# what is the HTTP response?
#
httpCode=$(echo $xmlResponse | tr ' ' '\n' | grep "<httpCode>")
#
# check if it good
#
if [[ $httpCode != "<httpCode>200</httpCode>" ]]; then
  echo "{\"message\": \"Maintenance mode? $httpCode\" }"
  exit 1
fi
#
# check if there is a code inside the response (it should not)
#
code=$(echo "$xmlResponse" | tr ' ' '\n' | grep "<code>")

if [ -n "$code" ]; then
  echo "{\"message\": \"Fetching data from $url failed with: $code\"}";
  exit 1
fi
#
# convert the XML to a JSON array using jtm, you can find it here: https://github.com/ldn-softdev/jtm
#
jsonResponse=$(echo "$xmlResponse" | sed "s#<httpCode>200</httpCode>##g" | xq )

echo "{"

echo "\"date\"": "\"$inDate\""
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
echo ", \"units\": \"$currency/$unit\""

max=100000
min=0

rm tmp.tmp

# find max min values
for i in {0..23}; do
  # get the prices for each hour
  if((count == 8)); then
  price=$(echo "$jsonResponse" | jq .Publication_MarketDocument.TimeSeries.Period.Point[$i] | sed "s/.amount/Amount/" | jq -r .priceAmount)
 else
   price=$(echo "$jsonResponse" | jq .Publication_MarketDocument.TimeSeries[0].Period.Point[$i] | sed "s/.amount/Amount/" | jq -r .priceAmount)
   fi
# differentiate on time (06-22) and (22-06), price needs to be in Euro cents.
netcosthigh=0.02175
netcostlow=0.010875

  if(( $i >= 6 && $i < 22 )); then
        price=$(echo "scale=2; ($price + $netcosthigh)*100.00/100.00" | bc -l );
      else
        price=$(echo "scale=2; ($price + $netcostlow)*100.00/100.00" | bc -l );
  fi

  # find highest price
  if (($(echo "$price > $min" | bc -l))); then
    min=$price
    maxIndex=$i
  fi
  # find lowest price
  if (($(echo "$price < $max" | bc -l))); then
    max=$price
    minIndex=$i
  fi
  priceArray+=$(echo "${price} ")

  echo "${price} " $i >> tmp.tmp

done

sortedHour=$(cat tmp.tmp | sort -nr | cut -d' ' -f3 )

echo ", \"maxHour\"": $maxIndex
echo ", \"minHour\"": $minIndex
echo ", \"price\": [$(echo $priceArray | tr ' ' ',')]"
echo ", \"sortedHour\": [$(echo $sortedHour | tr ' ' ',')]"
echo "}"
# color code the data
m=0
rm data-$today.plt
for k in $priceArray; do
  # color the histogram (7 - red, 2 - green)
  if [ $maxIndex -eq $m ]; then
    c=7
  else
    if [ $minIndex -eq $m ]; then
      c=2
    else
      c=0
    fi
  fi
  echo "$m.5 $k $c" >> data-$today.plt
  m=$(($m + 1))
done
if [ -z "$4" ]; then
  true
  exit 1
else
# plot the data in a diagram, result in "plot.png"
  gnuplot -c ../plot/plotPrices.gp data-$today.plt $inDate $currency $unit $plotfile
fi
