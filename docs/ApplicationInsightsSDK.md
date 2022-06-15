# Application Insights Availability SDK

Availability Test data can be shipped to Application Insights using Python and the [Application Insights SDK](https://shipit.dev/python-appinsights/)

Example

```
from applicationinsights import TelemetryClient

app_insights_instrumentation_key = '0ca425c9-6e7a-4abf-8849-b9fc5e1efcde'

tc = TelemetryClient(app_insights_instrumentation_key)

name = 'my test'
location = 'my location'
duration_ms = 500
success = False
message = 'reason test failed'

# optionally custom properties can be passed
custom_properties = { 'url': 'https://example.com', 'status_code': 403}

# send results
tc.track_availability( name, duration_ms, success, location, message=message, properties=custom_properties )
tc.flush()

```






