# Electric Prices in Europe

## Introduction

This project shows you how to get the electric prices for your home automation project.

Data for Europe is available from this site: 
https://transparency.entsoe.eu/usrm/user/myAccountSettings 
where you have to sign up for a security token to get access.

The documentation for the API is here:
https://transparency.entsoe.eu/content/static_content/Static%20content/web%20api/Guide.html

## Usage

This project shows how you can let your home automation decide what to do when the electric price is high or low.
And also how to plot a daily diagram as well, like this:

![price pr hour](https://raw.githubusercontent.com/sunejak/ElectricPrices/main/src/main/sh/plot.png)

The data returned from the API is in XML, and to do fun stuff with it, the data is converted to a JSON data structure.

Like this, where price is an array where the elements are price at that hour. 
Example, array element [0] contains the price between 0:00 and 1:00, and element [23]
contains the price between 23:00 and 24:00
```json
{
  "date": "2023-03-20"
, "units": "EUR/MWH"
, "maxHour": 11
, "minHour": 23
, "price": [39.28,39.92,42.72,42.49,44.82,46.61,44.10,53.01,53.02,52.87,50.37,53.29,53.01,52.48,52.74,53.27,53.02,53.01,47.97,46.65,46.81,42.85,39.72,37.83]
, "sortedHour": [11,15,8,16,7,17,12,9,14,13,10,18,20,19,5,4,6,21,2,3,1,22,0,23]
}


```
Time is shown as hour in Norway. 
The parameters for the script are:
- Security token
- Date, any legal value you can feed to the "date" command
- Norwegian area, like Oslo/Bergen/Trondheim/Tromsø/Kristiansand
- Output file for plot (if omitted, no plot is generated)

Since 1 July 2022, there is now differentiated prices on power.

Daytime price 06-22, nighttime 22-06. For Tensio NT ( 21.75 øre/kWh and 10.875 øre/kWh )

The usage pattern is a crontab like this (NB, prices are updated at 14:00):
```shell
0 14 * * * 	cd /home/directory/ElectricPrices/src/main/sh; ./getDataFromEntsoe.sh security-token tomorrow Trondheim plot.png > result.json
```
The project depends on bash scripting, gnuplot, jq and jtm, they are installed with:

- sudo apt install curl 
- sudo apt install gnuplot 
- sudo apt install jq
- sudo pip install xq https://www.howtogeek.com/devops/how-to-convert-xml-to-json-on-the-command-line/

curl -s https://www.hvakosterstrommen.no/strompris-api is also an alternative to fetch electric prices.

Get today's exchange rate, from Norges Bank
curl -s "https://data.norges-bank.no/api/data/EXR/B.EUR.NOK.SP?format=sdmx-json&startPeriod=2022-11-27&endPeriod=2022-11-27&locale=no" | jq '.data.dataSets[0].series' | sed "s/0:0:0:0/testing/" | jq .testing.observations | sed 's/"0"/"test"/g' | jq -r .test[0]
