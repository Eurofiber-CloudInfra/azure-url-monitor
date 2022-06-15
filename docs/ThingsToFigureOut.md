
# Where to store valid status codes?

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

# Where to store container application logs?

- An Azure Container Instances deployment allows to [specify](https://docs.microsoft.com/en-us/azure/container-instances/container-instances-log-analytics) a Log Analytics Workspace for logging 
- Alternatively the logs could also be send to Application Insights using [`track_trace` method ](https://shipit.dev/python-appinsights/applicationinsights.html#applicationinsights.TelemetryClient.track_trace) from the SDK since we already have the instrumentation key

