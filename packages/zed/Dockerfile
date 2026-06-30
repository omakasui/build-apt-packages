# Upstream: https://github.com/zed-industries/zed

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN set -e; \
    case "${TARGETARCH}" in \
      amd64)  UPSTREAM_ARCH="x86_64"  ;; \
      arm64)  UPSTREAM_ARCH="aarch64" ;; \
      *)      echo "ERROR: unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL \
      "https://github.com/zed-industries/zed/releases/download/v${VERSION}/zed-linux-${UPSTREAM_ARCH}.tar.gz" \
      -o zed.tar.gz; \
    mkdir -p zed.app; \
    tar -xzf zed.tar.gz -C zed.app --strip-components=1

RUN set -e; \
    mkdir -p staged/opt/zed.app; \
    cp -r zed.app/. staged/opt/zed.app/; \
    chmod 755 staged/opt/zed.app/bin/zed; \
    \
    mkdir -p staged/usr/bin; \
    ln -sf /opt/zed.app/bin/zed staged/usr/bin/zed; \
    \
    mkdir -p staged/usr/share/icons/hicolor/512x512/apps; \
    cp zed.app/share/icons/hicolor/512x512/apps/zed.png \
       staged/usr/share/icons/hicolor/512x512/apps/zed.png; \
    \
    mkdir -p staged/usr/share/applications; \
    sed \
      -e 's|^Exec=zed|Exec=/opt/zed.app/bin/zed|' \
      zed.app/share/applications/dev.zed.Zed.desktop \
      > staged/usr/share/applications/dev.zed.Zed.desktop

# Copy staged tree to output for external assembly by build.sh.
RUN mkdir -p /output/staged && cp -r staged/. /output/staged/

RUN echo "Staged: $(find /output/staged -type f | wc -l) files"
