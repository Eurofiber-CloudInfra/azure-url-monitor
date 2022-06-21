import os
from applicationinsights import TelemetryClient

ai_instrumentation_key = os.environ['AI_INSTRUMENTATION_KEY']
tc = TelemetryClient(ai_instrumentation_key)
web_tests_names = [
    'alert test 1',
    'alert test 2',
    'alert test 3'
]

for web_test_name in web_tests_names:
    name = web_test_name
    location = 'my location'
    duration_ms = 100
    success = True
    message = 'reason test failed ' 
    tc.track_availability( name, duration_ms, success, location, message=message)
    tc.flush()

