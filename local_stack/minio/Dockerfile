# MinIO no longer publishes container images: its Docker Hub repositories are
# deleted and its quay.io repositories refuse anonymous pulls (#9208). The
# community edition ships as source, so this builds the server and client
# releases that docker-compose.yml pins, from their upstream commits.
#
# `go install module@commit` resolves through the Go module proxy and checks
# the source against the public checksum database (sum.golang.org).

ARG GO_IMAGE=golang:1.27-alpine
ARG RUNTIME_IMAGE=alpine:3.24

FROM ${GO_IMAGE} AS build-server
ARG MINIO_RELEASE
ARG MINIO_COMMIT
ENV CGO_ENABLED=0
COPY install.sh /usr/local/bin/install-minio-module
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    install-minio-module github.com/minio/minio "${MINIO_RELEASE}" "${MINIO_COMMIT}"

FROM ${GO_IMAGE} AS build-client
ARG MC_RELEASE
ARG MC_COMMIT
ENV CGO_ENABLED=0
COPY install.sh /usr/local/bin/install-minio-module
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    install-minio-module github.com/minio/mc "${MC_RELEASE}" "${MC_COMMIT}"

# curl backs the compose healthcheck, as it did in the published image. So does
# the /data volume: compose carries an anonymous volume over when it recreates
# the container, which keeps seeded blobs in step with the relay's seed events.
FROM ${RUNTIME_IMAGE} AS server
RUN apk add --no-cache ca-certificates curl
COPY --from=build-server /go/bin/minio /usr/bin/minio
VOLUME ["/data"]
EXPOSE 9000 9001
ENTRYPOINT ["minio"]

# minio-init runs its bucket setup through /bin/sh, which alpine provides.
FROM ${RUNTIME_IMAGE} AS client
RUN apk add --no-cache ca-certificates
COPY --from=build-client /go/bin/mc /usr/bin/mc
ENTRYPOINT ["mc"]
