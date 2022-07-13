ARG ALPINE_VER=3.15

FROM node:14-alpine${ALPINE_VER} AS node
WORKDIR /build
RUN npm install newman

FROM python:3.10-alpine${ALPINE_VER} AS python
WORKDIR /build
RUN set -ex \
  && apk add --no-cache gcc g++ linux-headers libffi-dev \
  && pip install pipenv
COPY Pipfile* ./
RUN set -ex \
  && pipenv lock -r > requirements.txt \
  && pip wheel -r requirements.txt --prefer-binary

FROM python:3.10-alpine${ALPINE_VER} AS runtime
WORKDIR /tmp/wheelhouse
COPY --from=python --chown=root:root /build/*.whl ./
RUN set -ex \
  && apk add --no-cache tini nodejs \
  && pip install *.whl \
  && rm -rf $PWD
WORKDIR /runtime
COPY --from=node --chown=root:root /build/ ./
COPY docker/entrypoint.sh /
ENV PATH "$PATH:/runtime/node_modules/.bin/"
ARG \
  PUID=1000
RUN set -ex \
  && adduser -g "" -u ${PUID} -h $PWD -D runtime \
  && chmod +x /entrypoint.sh

ENV \
  DEBUG=NO \
  AI_INSTRUMENTATION_KEY= \
  PM_COLLECTION_URL= \
  NM_TIMEOUT_COLLECTION= \
  NM_TIMEOUT_REQUEST= \
  NM_TIMEOUT_SCRIPT= \
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
