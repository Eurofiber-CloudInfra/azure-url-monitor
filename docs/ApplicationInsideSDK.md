# Application Insights Availability SDK

Availability Test data can be shipped to Application Insights using Python and the [Application Insights SDK](https://shipit.dev/python-appinsights/)index.html)

Example

```
from applicationinsights import TelemetryClient

app_insights_instrumentation_key = '<GUID>'

tc = TelemetryClient(app_insights_instrumentation_key)

name = 'my test'
location = 'my location'
duration_ms = 500
success = True


# optionally custom properties can be passed
custom_properties = { 'url': 'https://example.com', 'status_code': 200, 'reason': 'reason why test failed'}

# send results
tc.track_availability( name, duration_ms, success, location , properties = custom_properties)
tc.flush()

```






