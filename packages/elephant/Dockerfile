# Upstream: https://github.com/abenz1267/elephant

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

ENV ELEPHANT_PROVIDERS="\
  1password \
  bitwarden \
  bluetooth \
  bookmarks \
  calc \
  clipboard \
  desktopapplications \
  files \
  menus \
  niriactions \
  nirisessions \
  playerctl \
  providerlist \
  runner \
  snippets \
  symbols \
  todo \
  unicode \
  websearch \
  windows \
  wireplumber \
"

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    golang \
    protobuf-compiler \
    gcc \
    libc6-dev \
    fakeroot \
  && rm -rf /var/lib/apt/lists/*

# Install protoc-gen-go.
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@latest && \
    go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

ARG VERSION
ARG TARGETARCH
ARG SUITE

WORKDIR /build

COPY packaging/ /tmp/pkgmeta/

RUN git clone --depth 1 --branch "v${VERSION}" \
    https://github.com/abenz1267/elephant.git elephant

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
RUN for provider in $ELEPHANT_PROVIDERS; do \
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

# Assemble .deb

RUN set -e; \
    ARCH="${TARGETARCH:-amd64}"; \
    PKG="elephant"; \
    ROOT="/output/deb/${PKG}"; \
    mkdir -p "${ROOT}/DEBIAN" "${ROOT}/usr/bin" "${ROOT}/usr/share/doc/${PKG}"; \
    install -m 0755 /tmp/elephant "${ROOT}/usr/bin/elephant"; \
    SIZE=$(du -sk "${ROOT}/usr/bin" | cut -f1); \
    DATE=$(date -R); \
    cp /tmp/pkgmeta/control "${ROOT}/DEBIAN/control"; \
    sed -i \
      -e "s|@VERSION@|${VERSION}|g" \
      -e "s|@SUITE@|${SUITE}|g" \
      -e "s|@ARCH@|${ARCH}|g" \
      -e "s|@INSTALLED_SIZE@|${SIZE}|g" \
      "${ROOT}/DEBIAN/control"; \
    sed \
      -e "s|@PACKAGE@|${PKG}|g" \
      -e "s|@VERSION@|${VERSION}|g" \
      -e "s|@SUITE@|${SUITE}|g" \
      -e "s|@DATE@|${DATE}|g" \
      /tmp/pkgmeta/changelog | gzip -9 -n > "${ROOT}/usr/share/doc/${PKG}/changelog.Debian.gz"; \
    cp /tmp/pkgmeta/copyright "${ROOT}/usr/share/doc/${PKG}/copyright"; \
    fakeroot dpkg-deb --build "${ROOT}" \
      "/output/elephant_${VERSION}-1+${SUITE}_${ARCH}.deb"; \
    echo "Built: $(ls -lh /output/elephant_${VERSION}-1+${SUITE}_${ARCH}.deb)"

# Assemble one .deb per provider plugin

RUN set -e; \
    ARCH="${TARGETARCH:-amd64}"; \
    DATE=$(date -R); \
    for provider in $ELEPHANT_PROVIDERS; do \
      SO="/tmp/${provider}.so"; \
      [ -f "$SO" ] || { echo "SKIP: ${provider}.so not built"; continue; }; \
      PKG="elephant-${provider}"; \
      ROOT="/output/deb/${PKG}"; \
      mkdir -p "${ROOT}/DEBIAN" "${ROOT}/usr/lib/elephant" "${ROOT}/usr/share/doc/${PKG}"; \
      install -m 0755 "$SO" "${ROOT}/usr/lib/elephant/${provider}.so"; \
      SIZE=$(du -sk "${ROOT}/usr/lib/elephant" | cut -f1); \
      CTRL_SRC="/tmp/pkgmeta/control.${PKG}"; \
      [ -f "$CTRL_SRC" ] || CTRL_SRC="/tmp/pkgmeta/control.default"; \
      cp "$CTRL_SRC" "${ROOT}/DEBIAN/control"; \
      sed -i \
        -e "s|@PACKAGE@|${PKG}|g" \
        -e "s|@VERSION@|${VERSION}|g" \
        -e "s|@SUITE@|${SUITE}|g" \
        -e "s|@ARCH@|${ARCH}|g" \
        -e "s|@INSTALLED_SIZE@|${SIZE}|g" \
        "${ROOT}/DEBIAN/control"; \
      sed \
        -e "s|@PACKAGE@|${PKG}|g" \
        -e "s|@VERSION@|${VERSION}|g" \
        -e "s|@SUITE@|${SUITE}|g" \
        -e "s|@DATE@|${DATE}|g" \
        /tmp/pkgmeta/changelog | gzip -9 -n > "${ROOT}/usr/share/doc/${PKG}/changelog.Debian.gz"; \
      cp /tmp/pkgmeta/copyright "${ROOT}/usr/share/doc/${PKG}/copyright"; \
      fakeroot dpkg-deb --build "${ROOT}" \
        "/output/${PKG}_${VERSION}-1+${SUITE}_${ARCH}.deb"; \
      echo "Built: $(ls -lh /output/${PKG}_${VERSION}-1+${SUITE}_${ARCH}.deb)"; \
    done