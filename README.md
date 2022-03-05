# Electric Prices

Shows you how to get the tric prices for your home automation project

This project shows how you can let your home automation decide when the price is high or low.

Data for Europe is available from this site: https://transparency.entsoe.eu/usrm/user/myAccountSettings where you have to sign up for a security token.

The API itself id decribed here: https://transparency.entsoe.eu/content/static_content/Static%20content/web%20api/Guide.html

The data returned from the API is in XML, and to do fun stuff with it the data is converted to a JSON data structure.

Like this: 

{
	"highHour": 123456,
	"lowHour": 54321,
	"date": "2022-03-03",
	"price": [1.10, 2.15, 3.3, 4, 5, 6, 7, 8, 9, 10, 11],
	"units": "EUR/MWh"
}
