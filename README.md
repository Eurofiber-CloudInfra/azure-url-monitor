# Azure URL Monitor

Slightly more advanced version of the URL monitor tool of Azure that stores the results in a Log Analytics Workspace.

Goals:
- [ ] Can run quickly as cron job
- [ ] Measurements in nanoseconds
- [ ] Support of multiple tests in parallel
- [ ] Results should be stored in the Azure Log Analytics Workspace
- [ ] Can run on a VM and as Docker container
- [ ] Tests should be defined in Postman
- [ ] Retrieve certificate expiration date and store this
- [ ] If the monitor fails sufficient log information should be available to generate an alert

Nice to have:
- [ ] A cool name
- [ ] Support for Kubernetes
- [ ] Cloud-init setup ready to roll
- [ ] Fun

## Run locally

Please ensure you have curl and curllib installed on your machine.
Also install dependencies using: `pip install -r requirements.txt`

Start using `python monitor.py`

## Run as container

Build the container using Dockerfile

