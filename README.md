# Electric Prices

## Introduction

This project shows you how to get the electric prices for your home automation project

Data for Europe is available from this site: https://transparency.entsoe.eu/usrm/user/myAccountSettings where you have to sign up for a security token.

The API itself is decribed here: https://transparency.entsoe.eu/content/static_content/Static%20content/web%20api/Guide.html

## Usage

This project shows how you can let your home automation decide when the price is high or low.

The data returned from the API is in XML, and to do fun stuff with it, the data is converted to a JSON data structure.

Like this: 
```
{
	"highHour": 123456,
	"lowHour": 54321,
	"date": "2022-03-03",
	"price": [1.10, 2.15, 3.3, 4, 5, 6, 7, 8, 9, 10, 11],
	"units": "EUR/MWh"
}
```
Time is shown in seconds since 1 Jan 1970 and date in ISO format. 
The usage pattern is a crontab like this:

