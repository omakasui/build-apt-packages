# Installs to /opt/kitty; symlinks kitty and kitten into /usr/bin.
# Upstream: https://github.com/kovidgoyal/kitty

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    xz-utils \
  && rm -rf /var/lib/apt/lists/*

# Map Docker TARGETARCH to kitty's archive naming convention.
RUN case "${TARGETARCH}" in \
      amd64) echo "x86_64" > /tmp/kitty_arch ;; \
      arm64) echo "arm64"  > /tmp/kitty_arch ;; \
      *) echo "ERROR: unsupported arch ${TARGETARCH}" >&2; exit 1 ;; \
    esac

RUN KITTY_ARCH=$(cat /tmp/kitty_arch) && \
    curl -fsSL \
      "https://github.com/kovidgoyal/kitty/releases/download/v${VERSION}/kitty-${VERSION}-${KITTY_ARCH}.txz" \
      -o /tmp/kitty.txz && \
    mkdir -p /tmp/kitty-bundle && \
    tar -xJf /tmp/kitty.txz -C /tmp/kitty-bundle

# Stage the bundle, symlinks, desktop entries and icons.
RUN set -e && \
    STAGED=/tmp/staged && \
    mkdir -p "${STAGED}/opt/kitty" && \
    cp -a /tmp/kitty-bundle/. "${STAGED}/opt/kitty/" && \
    \
    mkdir -p "${STAGED}/usr/bin" && \
    ln -s /opt/kitty/bin/kitty  "${STAGED}/usr/bin/kitty" && \
    ln -s /opt/kitty/bin/kitten "${STAGED}/usr/bin/kitten" && \
    \
    mkdir -p "${STAGED}/usr/share/applications" && \
    cp /tmp/kitty-bundle/share/applications/kitty.desktop \
       "${STAGED}/usr/share/applications/kitty.desktop" && \
    cp /tmp/kitty-bundle/share/applications/kitty-open.desktop \
       "${STAGED}/usr/share/applications/kitty-open.desktop" 2>/dev/null || true && \
    \
    sed -i \
      -e "s|Exec=kitty|Exec=/opt/kitty/bin/kitty|g" \
      -e "s|Icon=kitty|Icon=/opt/kitty/share/icons/hicolor/256x256/apps/kitty.png|g" \
      "${STAGED}/usr/share/applications/"*.desktop && \
    \
    for SIZE in 16 32 48 64 128 256 512; do \
      SRC="/tmp/kitty-bundle/share/icons/hicolor/${SIZE}x${SIZE}/apps/kitty.png"; \
      [[ -f "$SRC" ]] || continue; \
      DEST="${STAGED}/usr/share/icons/hicolor/${SIZE}x${SIZE}/apps"; \
      mkdir -p "$DEST" && cp "$SRC" "$DEST/kitty.png"; \
    done

# Copy staged tree to output for external assembly by build.sh.
RUN mkdir -p /output/staged && cp -a /tmp/staged/. /output/staged/

RUN echo "Staged: $(find /output/staged -type f | wc -l) files"