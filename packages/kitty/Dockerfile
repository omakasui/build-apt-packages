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
    fakeroot \
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

# Write DEBIAN/control and assemble .deb.
RUN set -e && \
    STAGED=/tmp/staged && \
    DEB_ROOT="/tmp/deb-kitty" && \
    mkdir -p "${DEB_ROOT}/DEBIAN" && \
    cp -a "${STAGED}/." "${DEB_ROOT}/" && \
    SIZE=$(du -sk "$STAGED" | cut -f1) && \
    printf "Package: kitty\n"                                          >  "${DEB_ROOT}/DEBIAN/control" && \
    printf "Version: %s\n"         "${VERSION}"                        >> "${DEB_ROOT}/DEBIAN/control" && \
    printf "Architecture: %s\n"    "${TARGETARCH}"                     >> "${DEB_ROOT}/DEBIAN/control" && \
    printf "Maintainer: omakasui <packages@omakasui.org>\n"            >> "${DEB_ROOT}/DEBIAN/control" && \
    printf "Installed-Size: %s\n"  "${SIZE}"                           >> "${DEB_ROOT}/DEBIAN/control" && \
    printf "Conflicts: kitty\n"                                        >> "${DEB_ROOT}/DEBIAN/control" && \
    printf "Replaces: kitty\n"                                         >> "${DEB_ROOT}/DEBIAN/control" && \
    printf "Provides: kitty\n"                                         >> "${DEB_ROOT}/DEBIAN/control" && \
    printf "Section: x11\n"                                            >> "${DEB_ROOT}/DEBIAN/control" && \
    printf "Priority: optional\n"                                      >> "${DEB_ROOT}/DEBIAN/control" && \
    printf "Homepage: https://sw.kovidgoyal.net/kitty/\n"              >> "${DEB_ROOT}/DEBIAN/control" && \
    printf "Description: GPU-accelerated terminal emulator\n"          >> "${DEB_ROOT}/DEBIAN/control" && \
    printf " Self-contained bundle installed to /opt/kitty.\n"         >> "${DEB_ROOT}/DEBIAN/control" && \
    \
    mkdir -p /output && \
    fakeroot dpkg-deb --build "${DEB_ROOT}" \
      "/output/kitty_${VERSION}_${TARGETARCH}.deb" && \
    echo "Built: $(ls -lh /output/kitty_${VERSION}_${TARGETARCH}.deb)"