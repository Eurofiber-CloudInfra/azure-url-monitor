
# Where to store valid status codes

- By default expect 200 and for additional valid status codes rely on Postman Test configured with the request?
- Would it be possible run  simple javascript tests from the Postman Collection export /  use `newman`?

Example config 
```
	"item": [
		{
			"name": "Simple Get",
			"event": [
				{
					"listen": "test",
					"script": {
						"exec": [
							"pm.test(\"Status code is 300\", function () {",
							"    pm.response.to.have.status(300);",
							"});"
						],
						"type": "text/javascript"
					}
				}
			],
			"request": {
				"method": "GET",
				"header": [],
				"url": {
					"raw": "https://www.google.com",
					"protocol": "https",
					"host": [
						"www",
						"google",
						"com"
					]
				}
			},
			"response": []
		}
	]

```



