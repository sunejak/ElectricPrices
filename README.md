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
"date": "2022-03-06"
, "units": "EUR/MWH"
, "maxHour": 23
, "minHour": 0
, "price": [13.55,13.75,13.81,13.75,13.81,13.55,13.93,14.03,14.19,14.27,14.25,14.13,13.73,13.64,13.64,13.92,14.07,14.18,14.30,14.38,14.43,14.54,14.65,14.91]
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
- jtm, download it from here: https://github.com/ldn-softdev/jtm 


