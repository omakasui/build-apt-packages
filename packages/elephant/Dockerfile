# Builds elephant daemon and all provider plugins from source (Go).
# IMPORTANT: elephant and all .so plugins MUST be compiled in the same build
# context so that internal Go package build IDs match — otherwise the plugin
# loader will reject them at runtime with "different version of package".
# Upstream: https://github.com/abenz1267/elephant

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    golang \
    protobuf-compiler \
    gcc \
    libc6-dev \
    fakeroot \
    dpkg-dev \
  && rm -rf /var/lib/apt/lists/*

# Install protoc-gen-go.
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@latest && \
    go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

ARG VERSION
ARG TARGETARCH

WORKDIR /build

# RUN git clone --depth 1 --branch "v${VERSION}" \
#     https://github.com/abenz1267/elephant.git elephant
RUN git clone --depth 1 --branch "v${VERSION}" \
     https://github.com/omakasui/elephant.git elephant

WORKDIR /build/elephant

# Generate protobuf bindings.
RUN PATH="$PATH:$(go env GOPATH)/bin" go generate ./... 2>/dev/null || true

# Build main binary.
RUN go build \
    -ldflags="-s -w" \
    -buildvcs=false \
    -trimpath \
    -o /tmp/elephant \
    ./cmd/elephant

# Build all provider plugins in the same build context.
# Each provider is a Go plugin — they must share the same build environment
# as the main binary to avoid internal/goarch build ID mismatches.
RUN for provider in calc clipboard desktopapplications files menus providerlist runner symbols todo unicode websearch; do \
      PROVIDER_DIR="./internal/providers/${provider}"; \
      if [ -d "$PROVIDER_DIR" ]; then \
        CGO_ENABLED=1 go build \
          -ldflags="-s -w" \
          -buildvcs=false \
          -buildmode=plugin \
          -trimpath \
          -o "/tmp/${provider}.so" \
          "$PROVIDER_DIR" && \
          echo "Built: ${provider}.so"; \
      else \
        echo "WARNING: provider dir not found: ${PROVIDER_DIR}"; \
      fi; \
    done

# ── Assemble .deb for elephant (main binary) ────────────────────────────────

RUN set -e; \
    ARCH="${TARGETARCH:-amd64}"; \
    PKG="elephant"; \
    ROOT="/output/deb/${PKG}"; \
    mkdir -p "${ROOT}/DEBIAN" "${ROOT}/usr/bin"; \
    install -m 0755 /tmp/elephant "${ROOT}/usr/bin/elephant"; \
    SIZE=$(du -sk "${ROOT}/usr/bin" | cut -f1); \
    printf "Package: %s\nVersion: %s\nArchitecture: %s\nMaintainer: omakasui <packages@omakasui.org>\nInstalled-Size: %s\nSection: utils\nPriority: optional\nHomepage: https://github.com/abenz1267/elephant\nDescription: Elephant - powerful data provider daemon for application launchers.\n Communicates via Unix sockets and Protocol Buffers.\n Install provider packages to add functionality.\n" \
      "$PKG" "$VERSION" "$ARCH" "$SIZE" > "${ROOT}/DEBIAN/control"

COPY postinst /output/deb/elephant/DEBIAN/postinst
RUN chmod 0755 /output/deb/elephant/DEBIAN/postinst

RUN set -e; \
    ARCH="${TARGETARCH:-amd64}"; \
    mkdir -p /output; \
    fakeroot dpkg-deb --build "/output/deb/elephant" \
      "/output/elephant_${VERSION}_${ARCH}.deb"; \
    echo "Built: $(ls -lh /output/elephant_${VERSION}_${ARCH}.deb)"

# ── Assemble one .deb per provider plugin ───────────────────────────────────

RUN set -e; \
    ARCH="${TARGETARCH:-amd64}"; \
    for provider in calc clipboard desktopapplications files menus providerlist runner symbols todo unicode websearch; do \
      SO="/tmp/${provider}.so"; \
      [ -f "$SO" ] || { echo "SKIP: ${provider}.so not built"; continue; }; \
      PKG="elephant-${provider}"; \
      ROOT="/output/deb/${PKG}"; \
      mkdir -p "${ROOT}/DEBIAN" "${ROOT}/usr/lib/elephant"; \
      install -m 0755 "$SO" "${ROOT}/usr/lib/elephant/${provider}.so"; \
      SIZE=$(du -sk "${ROOT}/usr/lib/elephant" | cut -f1); \
      EXTRA_DEPS=""; \
      case "$provider" in \
        calc)  EXTRA_DEPS=", qalc" ;; \
        files) EXTRA_DEPS=", fd-find" ;; \
      esac; \
      printf "Package: %s\nVersion: %s\nArchitecture: %s\nMaintainer: omakasui <packages@omakasui.org>\nInstalled-Size: %s\nDepends: elephant (= %s)%s\nSection: utils\nPriority: optional\nHomepage: https://github.com/abenz1267/elephant\nDescription: Elephant ${provider} provider plugin for the walker application launcher.\n Installs ${provider}.so into /usr/lib/elephant/.\n" \
        "$PKG" "$VERSION" "$ARCH" "$SIZE" "$VERSION" "$EXTRA_DEPS" > "${ROOT}/DEBIAN/control"; \
      if [ "$provider" = "files" ]; then \
        printf '#!/bin/sh\nset -e\ncase "$1" in\n  configure)\n    if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then\n      ln -sf /usr/bin/fdfind /usr/local/bin/fd\n    fi\n    ;;\nesac\nexit 0\n' > "${ROOT}/DEBIAN/postinst"; \
        chmod 0755 "${ROOT}/DEBIAN/postinst"; \
      fi; \
      fakeroot dpkg-deb --build "${ROOT}" \
        "/output/${PKG}_${VERSION}_${ARCH}.deb"; \
      echo "Built: $(ls -lh /output/${PKG}_${VERSION}_${ARCH}.deb)"; \
    done