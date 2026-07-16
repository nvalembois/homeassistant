ARG VIRTUAL_ENV=/srv/homeassistant
ARG USER_NAME=homeassistant
ARG USER_ID=1000

FROM docker.io/library/python:3.14.6@sha256:311ea5bb79f1a238ee9e38f8d5f09cb3b4b244575cf49e27cf365ea7e60f11d4 AS build

# renovate: datasource=github-releases depName=home-assistant/core
ARG HOMEASSISTANT_VERSION=2026.7.2
# renovate: datasource=pypi depName=imouapi
ARG IMOUAPI_VERSION=1.0.15
# renovate: datasource=pypi depName=uv
ARG UV_VERSION=0.11.29

ARG VIRTUAL_ENV

# Use Bash
# Install build packages
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install --yes \
       libffi-dev libssl-dev libjpeg-dev zlib1g-dev \
       libturbojpeg0-dev liblapack-dev \
       jq \
 && apt-get clean --yes

# Create homeassistant virtualenv
RUN pip3 install --no-build --no-cache "uv==${UV_VERSION}" wheel setuptools \
 && mkdir "${VIRTUAL_ENV}" \
 && python3 -m venv "${VIRTUAL_ENV}" \
 && . "${VIRTUAL_ENV}/bin/activate"
 
# Install homeassistant
ARG GHRC=https://raw.githubusercontent.com # gihub raw content
ARG HA_REPO=home-assistant/core

RUN uv pip install --compile --no-cache \
       -r "${GHRC}/${HA_REPO}/${HOMEASSISTANT_VERSION}/requirements.txt" \
 && uv pip install --compile --no-cache \
       -r "${GHRC}/${HA_REPO}/${HOMEASSISTANT_VERSION}/requirements_all.txt" \
 && uv pip install --compile --no-cache \
       psycopg2-binary \
       homeassistant==${HOMEASSISTANT_VERSION} \
       imouapi==${IMOUAPI_VERSION}

# Install HACS required python packages
COPY --chown=root:root --chmod=0644 hacs_repositories.json .
RUN url="${GHRC}"'/\(.repo)/refs/\(.ref)/custom_components/\(.name)/manifest.json' && \
  jq -r '.[]|"'"${url}"'"' hacs_repositories.json | \
  while read url; do \
    curl -s $url | \
      jq -r '.requirements.[]' | \
      uv pip install --compile --no-cache -r - ; \
  done

FROM docker.io/library/python:3.14.6-slim@sha256:d3400aa122fa42cf0af0dbe8ec3091b047eac5c8f7e3539f7135e86d855dc015

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes \
          bluez libffi8 libssl3t64 zlib1g libopenjp2-7 libtiff6 libturbojpeg0 \
          tzdata ffmpeg liblapack3 libatlas3-base && \
    DEBIAN_FRONTEND=noninteractive apt-get clean --yes
    
ARG USER_NAME
ARG USER_ID

RUN set -e \
 && install -d \
     -o "${USER_ID}" \
     -g root \
     -m 0750 \
     /config \
 && adduser -u "${USER_ID}" \
     --no-create-home \
     --disabled-password \
     --home /config \
     --comment 'Homeassistant user' \
     "${USER_NAME}"
    
ARG VIRTUAL_ENV
ENV PATH=${VIRTUAL_ENV}/bin:${PATH}
COPY --from=build $VIRTUAL_ENV $VIRTUAL_ENV

USER $USER_NAME

WORKDIR /config

ENTRYPOINT [ "" ]
CMD ["python3", "-m", "homeassistant", "--config", "/config"]
