# Builds elephant-calc provider plugin from source (Go).
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
    libqalculate-dev \
  && rm -rf /var/lib/apt/lists/*

ARG VERSION

WORKDIR /build

RUN curl -fsSL \
    "https://github.com/abenz1267/elephant/archive/refs/tags/v${VERSION}.tar.gz" \
    -o src.tar.gz && \
    tar -xzf src.tar.gz && \
    mv "elephant-${VERSION}" elephant

WORKDIR /build/elephant/internal/providers/calc

RUN CGO_ENABLED=1 go build \
    -ldflags="-s -w" \
    -buildvcs=false \
    -buildmode=plugin \
    -trimpath \
    -o calc.so .

RUN mkdir -p /output/staged/usr/lib/elephant && \
    install -m 0755 calc.so /output/staged/usr/lib/elephant/calc.so && \
    echo "Staged: $(ls -lh /output/staged/usr/lib/elephant/calc.so)"