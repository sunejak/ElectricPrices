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
areaInput=$3
#
inDate=$(date -I --date="$2")
if [ $? -ne 0 ]; then
  echo echo "{\"date\": \"$inDate\",\"error\": \"Not a valid date: $2\"}"
  exit 1
fi

today=$(echo "$inDate" | tr -d '-')

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
pEnd=${today}2359
secToken=$1
url=https://web-api.tp.entsoe.eu/api
#
# get the data, response is in XML format
#
url2use="$url?documentType=$dType&in_Domain=$inD&out_Domain=$outD&periodStart=$pStart&periodEnd=$pEnd&securityToken=xxxx";
resultUrl="$url?documentType=$dType&in_Domain=$inD&out_Domain=$outD&periodStart=$pStart&periodEnd=$pEnd&securityToken=$secToken"
echo $resultUrl

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
echo "$xmlResponse" | sed "s#<httpCode>200</httpCode>##g" > ${areaInput}_${inDate}.xml

