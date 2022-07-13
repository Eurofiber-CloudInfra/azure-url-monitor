# Table of Contents

1. [Introduction](#introduction)

## Introduction<a name="introduction"></a>

This project has been created because many of our Azure customers required to monitor privately exposed http endpoints. As [Azure Application Insights](https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview) only offers to run availability tests against publicly exposed endpoints and [Azure Connection Monitor](https://docs.microsoft.com/en-us/azure/network-watcher/connection-monitor-overview) didn't provide advanced enough http test configurations we decided to create an alternative solution. 

Because we :heart: [Postman](https://www.postman.com) we base the configuration of the availability tests on a Postman collection. The [Azure URL Monitor](https://github.com/Eurofiber-CloudInfra/azure-url-monitor) allows you to run these tests from anywhere in your network and store the results in an [Azure Application Insights](https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview) instance.

Next to running Postman collection tests the [Azure URL Monitor](https://github.com/Eurofiber-CloudInfra/azure-url-monitor) can run pro-active lifetime checks on SSL certificates. 

![concept](docs/images/azure-url-monitor-concept.drawio.png)

This project is still work in progress but we decide to make it public anyhow so others can benefit from it.


## Getting Started <a name="gettingstarted"></a>

The run the monitor successfully it needs the `Instrumentation Key` of your Application Insights instance and a url to your `Postman collection URL`.

The `Instrumentation Key` can be found in the Overview page of your Application Insights instance.

The `Postman collection URL` can be a url of either a [publicly shared Postman collection](https://learning.postman.com/docs/collaborating-in-postman/sharing/) using the JSON link option or to an [exported collection file](https://learning.postman.com/docs/getting-started/importing-and-exporting-data/#exporting-collections).  

If you don't have any thing setup yet but want to to try out the [Azure URL Monitor](https://github.com/Eurofiber-CloudInfra/azure-url-monitor) in your own environment we have a [bicep deployment](bicep/readme.md) available that deploys everything you need.

### Run Locally

Using your running Python environment:

- Optionally refresh the requirements file: `pipenv requirements > requirements.txt`

- Install dependencies using: `pip install -r requirements.txt`

Using `pipenv` to local virtual Python environment:

- Initialize project specific Python env: `pipenv install`

- Drop into virtual Python env: `pipenv shell`

Start using the main script:

- Run: `./monitor.py --help`
- Or: `python monitor.py --help`

Example
```
./monitor.py --ai-instrumentation-key  <your key> \
             --pm-collection-url <your collection url>

```

> **_NOTE:_**  The python code doesn't take care of scheduling. See [docker/entrypoint.sh](docker/entrypoint.sh) how this is handled inside a container.


### Run as a Container

Build the container:
```
docker build -t urlmonitor:latest --pull -f docker/Dockerfile .
```

Run the container:

```
docker run  -e AI_INSTRUMENTATION_KEY=<your key> \
            -e PM_COLLECTION_URL=<your collection url>\
            -e TEST_FREQUENCY_MINUTES=1 \
            urlmonitor
```

## Configuration Options

