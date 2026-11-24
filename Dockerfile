# Excalibur (camelot-dev/excalibur) for Railway.
# Upstream publishes no container image, so this builds the pinned v1.2.1
# release commit the same way upstream's own Dockerfile does (uv, frozen lock),
# then serves it with waitress behind HTTP basic auth.
FROM ghcr.io/astral-sh/uv:0.9.30@sha256:538e0b39736e7feae937a65983e49d2ab75e1559d35041f9878b7b7e51de91e4 AS uv

FROM python:3.12.16-slim@sha256:5e2bdb1b0d542d5039cffb8181c65930093949194a65c365dfb1b0fe13a4fa5b

ARG EXCALIBUR_VERSION=1.2.1
ARG EXCALIBUR_COMMIT=1f8bff8a2f062a5ce7e4be17b746e5a877c1ab09
ARG EXCALIBUR_SHA256=21c659205a28e6fd5a8af47e52e385a67877bda57c86cffe871172fae0dd8a25

COPY --from=uv /uv /usr/local/bin/uv

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never \
    PYTHONUNBUFFERED=1 \
    PATH=/app/.venv/bin:$PATH

WORKDIR /app

ADD --checksum=sha256:${EXCALIBUR_SHA256} \
    https://codeload.github.com/camelot-dev/excalibur/tar.gz/${EXCALIBUR_COMMIT} /tmp/excalibur.tar.gz

COPY requirements-extra.txt /tmp/requirements-extra.txt

RUN tar -xzf /tmp/excalibur.tar.gz --strip-components=1 -C /app \
 && rm /tmp/excalibur.tar.gz \
 && uv sync --frozen --no-dev \
 && uv pip install --python /app/.venv/bin/python --require-hashes -r /tmp/requirements-extra.txt \
 && rm -r /root/.cache /tmp/requirements-extra.txt \
 && rm -r /app/excalibur/www/static/uploads \
 && ln -s /data/uploads /app/excalibur/www/static/uploads \
 && useradd --uid 1000 --home-dir /data --no-create-home --shell /usr/sbin/nologin excalibur \
 && /app/.venv/bin/python -c "import excalibur, waitress; print(excalibur.__version__)" | grep -qx "${EXCALIBUR_VERSION}"

COPY railway_patch.py railway_serve.py /app/
COPY start.sh /usr/local/bin/excalibur-start
RUN chmod 755 /usr/local/bin/excalibur-start

ENV EXCALIBUR_HOME=/data \
    PORT=8080

EXPOSE 8080
CMD ["/usr/local/bin/excalibur-start"]
