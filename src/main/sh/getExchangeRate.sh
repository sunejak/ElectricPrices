#!/bin/bash
# Script to get last known exchange rate for EUR to NOK from Norges Bank
todaySeconds=$(date +%s)
# no rates for a weekend or holiday, so in case the API return "mes:Error" then try the day before
COUNTER=0
while [ $COUNTER -lt 10 ]; do
  oneDay=$(echo "$todaySeconds - (60*60*24*$COUNTER)" | bc)
  dateToUse=$(date -I --date=@"${oneDay}")
  resultUrl="https://data.norges-bank.no/api/data/EXR/B.EUR.NOK.SP?startPeriod=$dateToUse&endPeriod=$dateToUse"
  if ! xmlRawData=$(curl -s "$resultUrl"); then
    echo "Could not access URL at ${resultUrl}"
    exit 1
  fi
  # grab the line you want in the XML, if not try the day before
  observation=$(echo "$xmlRawData" | xmllint --format - | grep "OBS_VALUE")
  if [[ $observation == *OBS_VALUE* ]]; then
    exchange=$(echo $observation | tr '/' ' ' | cut -d' ' -f3 | cut -d'=' -f2 | tr -d '"')
    currentDate=$(echo $observation | tr '/' ' ' | cut -d' ' -f2 | cut -d'=' -f2 | tr -d '"')
    echo "{ \"exhangeRate\": ${exchange} , \"date\": \"${currentDate}\" }"
    exit 0
  fi
  (( COUNTER=COUNTER+1 ))
done
echo "Could not find exchange rate 10 days back in time"
exit 1
