FROM python:3.10-slim
LABEL maintainer="stefanelul2000"

ARG DEFAULT_REPO_BRANCH=master

ENV APP_DIR=/srv/app \
    UV_CACHE_DIR=/tmp/uv-cache \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    REPO_BRANCH=${DEFAULT_REPO_BRANCH}

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      git \
      build-essential; \
    rm -rf /var/lib/apt/lists/*

RUN python -m pip install --no-cache-dir --upgrade pip uv

WORKDIR ${APP_DIR}

COPY root/ /

RUN chmod +x /entrypoint.sh

VOLUME ${APP_DIR}

ENTRYPOINT ["/entrypoint.sh"]
