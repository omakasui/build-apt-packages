# Builds elephant-symbols provider plugin from source (Go).
# Upstream: https://github.com/abenz1267/elephant

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    golang \
    gcc \
    libc6-dev \
  && rm -rf /var/lib/apt/lists/*

ARG VERSION

WORKDIR /build

RUN curl -fsSL \
    "https://github.com/abenz1267/elephant/archive/refs/tags/v${VERSION}.tar.gz" \
    -o src.tar.gz && \
    tar -xzf src.tar.gz && \
    mv "elephant-${VERSION}" elephant

WORKDIR /build/elephant/internal/providers/symbols

RUN CGO_ENABLED=1 go build \
    -ldflags="-s -w" \
    -buildvcs=false \
    -buildmode=plugin \
    -trimpath \
    -o symbols.so .

RUN mkdir -p /output/staged/usr/lib/elephant && \
    install -m 0755 symbols.so /output/staged/usr/lib/elephant/symbols.so && \
    echo "Staged: $(ls -lh /output/staged/usr/lib/elephant/symbols.so)"