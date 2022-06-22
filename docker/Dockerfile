FROM python:3.10-slim

ARG \
  BUILD_DEPS="pipenv" \
  PUID=1000

RUN set -e \
  && apt update \
  && apt install -yq --no-install-recommends nodejs npm tini \
  && apt install -yq --no-install-recommends ${BUILD_DEPS}

WORKDIR /provisioning
COPY Pipfile* /provisioning/
RUN set -ex \
  && pipenv install --system --deploy \
  && npm install -g newman \
  && apt remove -yq --purge ${BUILD_DEPS} \
  && apt autoremove -yq \
  && apt autoclean -yq \
  && rm -rf /var/lib/apt/lists/*

COPY docker/entrypoint.sh /
RUN set -ex \
  && rm -rf /provisioning \
  && chmod +x /entrypoint.sh

WORKDIR /runtime
RUN set -ex \
  && adduser --home /runtime --no-create-home --uid ${PUID} --disabled-password --gecos "" runtime \
  && chown runtime /runtime

ENV \
  AI_INSTRUMENTATION_KEY= \
  PM_COLLECTION_URL= \
  TEST_FREQUENCY_MINUTES=5 \
  CERTIFICATE_VALIDATION_CHECK=YES \
  CERTIFICATE_IGNORE_SELF_SIGNED=NO \
  CERTIFICATE_CHECK_EXPIRATION=YES \
  CERTIFICATE_EXPIRATION_GRACETIME_DAYS=14 \
  AUTO_LOCATION_TEST_HOSTINFO=1.1.1.1:53:UDP \
  LOCATION=

USER runtime
COPY monitor.py /runtime/

ENTRYPOINT ["tini", "/entrypoint.sh"]
CMD []
