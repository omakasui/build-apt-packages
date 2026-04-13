# Upstream: https://github.com/fastfetch-cli/fastfetch

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    dpkg-dev \
  && rm -rf /var/lib/apt/lists/*

ARG VERSION
ARG TARGETARCH

WORKDIR /work

RUN set -e; \
    case "${TARGETARCH}" in \
      amd64) FF_ARCH="amd64" ;; \
      arm64) FF_ARCH="aarch64" ;; \
      *)     echo "Unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    \
    DEB="fastfetch-linux-${FF_ARCH}.deb"; \
    URL="https://github.com/fastfetch-cli/fastfetch/releases/download/${VERSION}/${DEB}"; \
    \
    echo "Downloading ${URL}..."; \
    curl -fsSL "${URL}" -o "${DEB}"; \
    \
    mkdir -p extracted; \
    dpkg-deb -R "${DEB}" extracted/; \
    \
    CTRL="extracted/DEBIAN/control"; \
    awk 'BEGIN{p=1} /^$/{p=0} p{print}' "$CTRL" > /tmp/control.clean && mv /tmp/control.clean "$CTRL"; \
    \
    # Remove conffiles if empty or containing blank lines — dpkg-deb rejects non-absolute paths. \
    if [ -f extracted/DEBIAN/conffiles ]; then \
      sed -i '/^[[:space:]]*$/d' extracted/DEBIAN/conffiles; \
      [ ! -s extracted/DEBIAN/conffiles ] && rm extracted/DEBIAN/conffiles; \
    fi; \
    \
    mkdir -p /output; \
    dpkg-deb -b extracted/ "/output/fastfetch_${VERSION}_${TARGETARCH}.deb"; \
    echo "Built: $(ls -lh /output/)"