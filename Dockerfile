FROM docker.io/library/python:3.14.3-slim@sha256:fb83750094b46fd6b8adaa80f66e2302ecbe45d513f6cece637a841e1025b4ca AS base

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes \
        bluez libffi8 libssl3t64 zlib1g libopenjp2-7 libtiff6 libturbojpeg0 \
        tzdata ffmpeg liblapack3 libatlas3-base && \
    DEBIAN_FRONTEND=noninteractive apt-get clean --yes

FROM base AS build

# renovate: datasource=github-releases depName=home-assistant/core
ARG HOMEASSISTANT_VERSION=2026.3.4
# renovate: datasource=pypi depName=imouapi
ARG IMOUAPI_VERSION=1.0.15

ARG VIRTUAL_ENV=/srv/homeassistant

RUN DEBIAN_FRONTEND=noninteractive apt-get install --yes \
        libffi-dev libssl-dev libjpeg-dev zlib1g-dev autoconf build-essential \
        libturbojpeg0-dev liblapack-dev python3-dev \
 && pip3 install --no-build --no-cache uv==0.1.43 wheel setuptools \
 && mkdir "${VIRTUAL_ENV}" \
 && python3 -m venv "${VIRTUAL_ENV}" \
 && . "${VIRTUAL_ENV}/bin/activate" \
 && uv pip install --compile --no-cache \
      -r https://raw.githubusercontent.com/home-assistant/core/${HOMEASSISTANT_VERSION}/requirements.txt \
 && uv pip install --compile --no-cache \
      -r https://raw.githubusercontent.com/home-assistant/core/${HOMEASSISTANT_VERSION}/requirements_all.txt \
 && uv pip install --compile --no-cache \
      psycopg2-binary \
 && uv pip install --compile --no-cache \
      homeassistant==${HOMEASSISTANT_VERSION} imouapi==${IMOUAPI_VERSION} \
 && DEBIAN_FRONTEND=noninteractive apt-get clean --yes

FROM base

ENV VIRTUAL_ENV=/srv/homeassistant
ENV PATH=${VIRTUAL_ENV}/bin:${PATH}

COPY --from=build $VIRTUAL_ENV $VIRTUAL_ENV

RUN set -e \
 && adduser -u 10000 --no-create-home --disabled-password --home /config --comment 'Homeassistant user' homeassistant \
 && install -d -o homeassistant -g root -m 0750 /config

USER homeassistant

 
WORKDIR /config

ENTRYPOINT [ "" ]
CMD ["python3", "-m", "homeassistant", "--config", "/config"]
