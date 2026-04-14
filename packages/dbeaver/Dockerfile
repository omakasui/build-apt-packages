# Repackages the upstream DBeaver Community Edition .deb.
# Downloads the prebuilt .deb from GitHub Releases for the target arch.
# Upstream: https://github.com/dbeaver/dbeaver

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
      amd64)  UPSTREAM_ARCH="x86_64"  ;; \
      arm64)  UPSTREAM_ARCH="aarch64" ;; \
      *)      echo "ERROR: unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac; \
    DEB_FILE="dbeaver-ce-${VERSION}-linux-${UPSTREAM_ARCH}.deb"; \
    curl -fsSL \
      "https://github.com/dbeaver/dbeaver/releases/download/${VERSION}/${DEB_FILE}" \
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
    dpkg-deb -b extracted "/output/dbeaver_${VERSION}_${TARGETARCH}.deb"; \
    echo "Built: $(ls -lh /output/dbeaver_${VERSION}_${TARGETARCH}.deb)"