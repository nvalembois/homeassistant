ARG VIRTUAL_ENV=/srv/homeassistant
ARG USER_NAME=homeassistant
ARG USER_ID=1000

FROM docker.io/library/python:3.14.6 AS build

# renovate: datasource=github-releases depName=home-assistant/core
ARG HOMEASSISTANT_VERSION=2026.6.3
# renovate: datasource=pypi depName=imouapi
ARG IMOUAPI_VERSION=1.0.15
# renovate: datasource=pypi depName=uv
ARG UV_VERSION=0.11.21

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
RUN uv pip install --compile --no-cache \
       -r https://raw.githubusercontent.com/home-assistant/core/${HOMEASSISTANT_VERSION}/requirements.txt \
 && uv pip install --compile --no-cache \
       -r https://raw.githubusercontent.com/home-assistant/core/${HOMEASSISTANT_VERSION}/requirements_all.txt \
 && uv pip install --compile --no-cache \
       psycopg2-binary \
       homeassistant==${HOMEASSISTANT_VERSION} \
       imouapi==${IMOUAPI_VERSION}

# Install HACS required python packages
COPY --chown=root:root --chmod=0644 hacs_repositories.json .
RUN jq -r '.[]|[.name,.repo,.ref]|join("#")' hacs_repositories.json \
 | while IFS='#' read name repo ref ; do \
     curl -s "https://raw.githubusercontent.com/${repo}/refs/${ref}/custom_components/${name}/manifest.json" \
     | jq -r '.requirements.[]' \
     | uv pip install --compile --no-cache -r - \
   ; done

FROM docker.io/library/python:3.14.6-slim

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
