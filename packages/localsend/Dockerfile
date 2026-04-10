# Repackages the upstream LocalSend .deb under the omakasui namespace.
# Downloads the prebuilt .deb from GitHub Releases for the target arch.
# Upstream: https://github.com/localsend/localsend
#
# Asset naming convention:
#   amd64 → LocalSend-<VERSION>-linux-x86-64.deb
#   arm64 → LocalSend-<VERSION>-linux-arm-64.deb

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    dpkg-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN set -e; \
    case "${TARGETARCH}" in \
      amd64)  UPSTREAM_ARCH="x86-64"  ;; \
      arm64)  UPSTREAM_ARCH="arm-64"  ;; \
      *)      echo "ERROR: unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac; \
    DEB_FILE="LocalSend-${VERSION}-linux-${UPSTREAM_ARCH}.deb"; \
    curl -fsSL \
      "https://github.com/localsend/localsend/releases/download/v${VERSION}/${DEB_FILE}" \
      -o upstream.deb; \
    \
    mkdir -p extracted; \
    dpkg-deb -R upstream.deb extracted; \
    \
    # Keep only the first stanza. \
    awk 'BEGIN{p=1} /^$/{p=0} p{print}' extracted/DEBIAN/control \
      > /tmp/control.clean && mv /tmp/control.clean extracted/DEBIAN/control; \
    \
    # Remove empty conffiles lines if present. \
    if [[ -f extracted/DEBIAN/conffiles ]]; then \
      sed -i '/^[[:space:]]*$/d' extracted/DEBIAN/conffiles; \
      [[ ! -s extracted/DEBIAN/conffiles ]] && rm extracted/DEBIAN/conffiles; \
    fi; \
    \
    mkdir -p /output; \
    dpkg-deb -b extracted "/output/localsend_${VERSION}_${TARGETARCH}.deb"; \
    echo "Built: $(ls -lh /output/localsend_${VERSION}_${TARGETARCH}.deb)"