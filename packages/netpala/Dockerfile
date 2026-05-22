# Upstream: https://github.com/joel-sgc/netpala

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Install Go 1.25.4 (matches go.mod minimum version).
ENV GOROOT=/usr/local/go
ENV PATH="${GOROOT}/bin:${PATH}"

RUN set -e; \
    GOTARBALL="go1.25.4.linux-${TARGETARCH}.tar.gz"; \
    curl -fsSL "https://go.dev/dl/${GOTARBALL}" -o "/tmp/${GOTARBALL}"; \
    tar -C /usr/local -xzf "/tmp/${GOTARBALL}"; \
    rm "/tmp/${GOTARBALL}"; \
    go version

WORKDIR /build

RUN curl -fsSL \
    "https://github.com/joel-sgc/netpala/archive/refs/tags/v${VERSION}.tar.gz" \
    -o netpala.tar.gz && \
    tar -xzf netpala.tar.gz && \
    mv netpala-${VERSION} netpala

WORKDIR /build/netpala

RUN go build -v -trimpath -o netpala .

RUN install -Dm755 netpala /output/staged/usr/bin/netpala && \
    echo "Staged: $(ls -lh /output/staged/usr/bin/netpala)"
