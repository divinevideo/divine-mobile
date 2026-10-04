# syntax=docker/dockerfile:1
# Local-stack adapter: upstream owns the Worker and migration chain; this
# image supplies only local bindings and never copies upstream secret files.
FROM node:22.22.0-bookworm-slim@sha256:dd9d21971ec4395903fa6143c2b9267d048ae01ca6d3ea96f16cb30df6187d94
WORKDIR /app
ADD --checksum=sha256:c77c0657b5bcd6620d0d15997781c180a51075f149933e692b8649c654e6441f https://codeload.github.com/divinevideo/divine-name-server/tar.gz/ec9da7213b3cd12b3ccc57efdf83c2877772f6fc /tmp/source.tar.gz
RUN tar -xzf /tmp/source.tar.gz --strip-components=1 \
      --wildcards '*/package.json' '*/package-lock.json' '*/src' '*/migrations' \
    && rm /tmp/source.tar.gz \
    && npm ci
COPY wrangler.local.toml start.sh smoke.mjs ./
ENV WRANGLER_SEND_METRICS=false
EXPOSE 8787
ENTRYPOINT ["sh", "/app/start.sh"]
