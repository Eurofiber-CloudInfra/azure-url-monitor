# FROM postman/newman:5-alpine
FROM python:3.10-slim

USER root
WORKDIR /

ARG \
  BUILD_DEPS="pipenv" \
  ARG PUID=1000

RUN set -e \
  && apt update \
  && apt install -yq --no-install-recommends nodejs npm tini cron
RUN set -ex \
  && apt install -yq --no-install-recommends ${BUILD_DEPS}

WORKDIR /provisioning
ADD Pipfile* ./
RUN set -ex \
  && pipenv install --system --deploy \
  && npm install -g newman \
  && apt remove -yq --purge ${BUILD_DEPS} \
  && apt autoremove -yq \
  && apt autoclean -yq \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /
ADD docker/entrypoint.sh /
RUN set -ex \
  && rm -rf /provisioning \
  && chmod +x /entrypoint.sh

WORKDIR /runtime
RUN set -ex \
  && adduser --home /runtime --no-create-home --uid ${PUID} --disabled-login --disabled-password --gecos "" runtime \
  && chown runtime .

ENV \
  AI_INSTRUMENTATION_KEY= \
  PM_COLLECTION_URL= \
  TEST_FREQUENCY_MINUTES=5 \
  CERTIFICATE_VALIDATION_CHECK=YES \
  CERTIFICATE_IGNORE_SELF_SIGNED=NO \
  CERTIFICATE_CHECK_EXPIRATION=YES \
  CERTIFICATE_EXPIRATION_GRACETIME_DAYS=14 \
  LOCATION=

USER runtime
ADD monitor.py ./

ENTRYPOINT ["tini", "/entrypoint.sh"]
CMD []
