FROM docker.io/library/python:3.13.5-slim-bookworm@sha256:6544e0e002b40ae0f59bc3618b07c1e48064c4faed3a15ae2fbd2e8f663e8283

# renovate: datasource=github-releases depName=home-assistant/core
ARG HOMEASSISTANT_VERSION=2025.7.1
# renovate: datasource=pypi depName=imouapi
ARG IMOUAPI_VERSION=1.0.15

ARG VENV=/srv/homeassistant

RUN set -e \
 && DEBIAN_FRONTEND=noninteractive apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --yes \
        bluez libffi8 libssl3 zlib1g libopenjp2-7 libtiff6 libturbojpeg0 \
        tzdata ffmpeg liblapack3 libatlas3-base \
 && DEBIAN_FRONTEND=noninteractive apt-get install --yes --mark-auto \
        libffi-dev libssl-dev libjpeg-dev zlib1g-dev autoconf build-essential \
        libturbojpeg0-dev liblapack-dev libatlas-base-dev python3-dev \
 && mkdir "${VENV}" \
 && python3 -m venv "${VENV}" \
 && . "${VENV}/bin/activate" \
 && pip3 install --no-build --no-cache uv==0.1.43 wheel setuptools \
 && uv pip install --compile --no-cache \
      -r https://raw.githubusercontent.com/home-assistant/core/${HOMEASSISTANT_VERSION}/requirements.txt \
 && uv pip install --compile --no-cache \
      -r https://raw.githubusercontent.com/home-assistant/core/${HOMEASSISTANT_VERSION}/requirements_all.txt \
 && uv pip install --compile --no-cache \
      psycopg2-binary \
 && uv pip install --compile --no-cache \
      homeassistant==${HOMEASSISTANT_VERSION} imouapi==${IMOUAPI_VERSION} \
 && pip3 uninstall --yes uv wheel setuptools \
 && DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge --yes \
 && DEBIAN_FRONTEND=noninteractive apt-get clean --yes

RUN set -e \
 && adduser -u 10000 --no-create-home --disabled-password --home /config --comment 'Homeassistant user' homeassistant \
 && install -d -o homeassistant -g root -m 0750 /config

USER homeassistant

ENV VIRTUAL_ENV=${VENV}
ENV PATH=${VENV}/bin:${PATH}
 
WORKDIR /config

ENTRYPOINT [ "" ]
CMD ["python3", "-m", "homeassistant", "--config", "/config"]
