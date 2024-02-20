# syntax=docker/dockerfile:1-labs
FROM public.ecr.aws/docker/library/alpine:3.19 AS base
ENV TZ=UTC
WORKDIR /src

# source stage =================================================================
FROM base AS source

# get and extract source from git
ARG BRANCH
ARG VERSION
ADD https://github.com/robherley/snips.sh.git#${BRANCH:-v$VERSION} ./

# build stage ==================================================================
FROM base AS build-app
# required for go-sqlite3
ENV CGO_ENABLED=1 CGO_CFLAGS="-D_LARGEFILE64_SOURCE"

# dependencies
RUN apk add --no-cache build-base git && \
    apk add --no-cache go --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community

# build dependencies
COPY --from=source /src/go.mod /src/go.sum ./
RUN go mod download

# build app
COPY --from=source /src ./
ARG VERSION
ARG COMMIT=$VERSION
RUN mkdir /build && \
    go build -ldflags "-s -w" -o /build/

# runtime stage ================================================================
FROM base

ENV S6_VERBOSITY=0 S6_BEHAVIOUR_IF_STAGE2_FAILS=2 PUID=65534 PGID=65534
ENV SNIPS_DB_FILEPATH=/config/snips.db SNIPS_SSH_HOSTKEYPATH=/config/.keys/snips
ENV SNIPS_SSH_AUTHORIZEDKEYSPATH=/config/authorized_keys
ENV SNIPS_SSH_INTERNAL=ssh://0.0.0.0:1222 SNIPS_HTTP_INTERNAL=http://0.0.0.0:3002
WORKDIR /config
VOLUME /config
EXPOSE 1222 3002

# copy files
COPY --from=build-app /build /app
COPY ./rootfs/. /

# runtime dependencies
RUN apk add --no-cache tzdata s6-overlay curl

# run using s6-overlay
ENTRYPOINT ["/init"]
