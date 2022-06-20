# Azure URL Monitor

Slightly more advanced version of the URL monitor tool of Azure that stores the results in a Log Analytics Workspace.

Goals:
- [ ] Can run quickly as cron job
- [ ] Support of multiple tests in parallel
- [ ] Results should be stored in Application Insights using [AppAvailabilityResults](docs/ApplicationInsightsData.md) schema
- [ ] Can run on a VM and as Docker container
- [x] Tests should be defined in Postman
- [x] Retrieve certificate expiration date and store this
- [ ] If the monitor fails sufficient log information should be available to generate an alert
- [ ] <strike>Measurements in nanoseconds</strike> Note: this was deemed unnecessary

Nice to have:
- [ ] A cool name
- [ ] Support for Kubernetes
- [ ] Cloud-init setup ready to roll
- [ ] Automatically create Azure Monitoring Alerts for each test
- [ ] Fun

## External dependencies

- `newman` in your `$PATH` to run automated Postman Collection tests

> Installing Newman using NPM
> - Newman can be installed locally to this project together with an updated PATH export
>   ```
>   $ npm install newman
>   $ export PATH=$PWD/node_modules/.bin:$PATH
>   ```
> - Now run the Python specific initialization


## Run locally

Using your running Python environment:

- Optionally refresh the requirements file: `pipenv requirements > requirements.txt`

- Install dependencies using: `pip install -r requirements.txt`

Using `pipenv` to local virtual Python environment:

- Initialize project specific Python env: `pipenv install`

- Drop into virtual Python env: `pipenv shell`

Start using the main script:

- Run: `./monitor.py --help`
- Or: `python monitor.py --help`


## Run as container

Build the container using Dockerfile

## Azure Deployment Scenario For Private Endpoint Monitoring

![monitor-private-endpoints-azure.drawio](docs/monitor-private-endpoints-azure.drawio.svg)

## Internal data flow mapping

![data-processing-flow.drawio](docs/data-processing-flow.drawio.png)
