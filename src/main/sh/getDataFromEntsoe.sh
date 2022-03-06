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
delay=$(shuf -i 2-20 -n 1)
#
# get some sleep for the number of minutes
#
sleep ${delay}m
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
Tromsø | tromso)
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
url=https://transparency.entsoe.eu/api
#
# get the data, response is in XML format
#
resultUrl="$url?documentType=$dType&in_Domain=$inD&out_Domain=$outD&periodStart=$pStart&periodEnd=$pEnd&securityToken=$secToken"
xmlResponse=$(curl -s "$resultUrl")
#
# did it work?
#
if [ $? -ne 0 ]; then
  echo "Could not access URL at ${resultUrl}"
  exit 1
fi

code=$(echo $(echo $xmlResponse | tr ' ' '\n' | grep "<code>"))

if [ -z "$code" ]; then
  # successfully fetched data
  echo "{"
else
  echo Fetching data from $url failed with: "$code"
  exit 1
fi
#
# convert the XML to a JSON array using jtm, you can find it here: https://github.com/ldn-softdev/jtm
#
jsonResponse=$(echo "$xmlResponse" | ./jtm-linux-64.v2.09)

echo "\"date\"": "\"$inDate\""
#
# get currency (EUR) in currency_Unit.name
#
currency=$(echo "$jsonResponse" | jq .[1].Publication_MarketDocument[10].TimeSeries[4] | tr -d '.' | jq -r .currency_Unitname)
#
# get units (MWH)
#
unit=$(echo "$jsonResponse" | jq .[1].Publication_MarketDocument[10].TimeSeries[5] | tr -d '.' | jq -r .price_Measure_Unitname)
#
echo ", \"units\": \"$currency/$unit\""

max=100000
min=0
# find max min values
for i in {2..25}; do
  # get the prices for each hour
  price=$(echo "$jsonResponse" | jq .[1].Publication_MarketDocument[10].TimeSeries[7].Period[$i].Point[1] | sed "s/.amount/Amount/" | jq -r .priceAmount)
  j=$(($i - 2))
  # find highest price
  if (($(echo "$price > $min" | bc -l))); then
    min=$price
    maxIndex=$j
  fi
  # find lowest price
  if (($(echo "$price < $max" | bc -l))); then
    max=$price
    minIndex=$j
  fi
  priceArray+=$(echo "${price} ")
done

echo ", \"maxHour\"": $maxIndex
echo ", \"minHour\"": $minIndex
echo ", \"price\": [$(echo $priceArray | tr ' ' ',')]"
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
  gnuplot -c ../plot/plotPrices.gp data-$today.plt $inDate $currency $unit $4
fi
