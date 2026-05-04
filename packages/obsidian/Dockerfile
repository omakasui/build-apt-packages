# Upstream: https://github.com/obsidianmd/obsidian-releases

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    fakeroot \
    dpkg-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN set -e; \
    case "${TARGETARCH}" in \
      amd64)  TARBALL="obsidian-${VERSION}.tar.gz"       ;; \
      arm64)  TARBALL="obsidian-${VERSION}-arm64.tar.gz" ;; \
      *)      echo "ERROR: unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL \
      "https://github.com/obsidianmd/obsidian-releases/releases/download/v${VERSION}/${TARBALL}" \
      -o obsidian.tar.gz; \
    mkdir -p obsidian; \
    tar -xzf obsidian.tar.gz -C obsidian --strip-components=1

RUN set -e; \
    mkdir -p staged/opt/obsidian; \
    cp -r obsidian/. staged/opt/obsidian/; \
    chmod 755 staged/opt/obsidian/obsidian; \
    \
    mkdir -p staged/usr/bin; \
    ln -sf /opt/obsidian/obsidian staged/usr/bin/obsidian; \
    \
    mkdir -p staged/usr/share/applications; \
    printf '%s\n' \
      '[Desktop Entry]' \
      'Name=Obsidian' \
      'Comment=A powerful knowledge base that works on top of local Markdown files' \
      'Keywords=notes;markdown;knowledge;pkm;wiki' \
      'Exec=/opt/obsidian/obsidian %u' \
      'Icon=/opt/obsidian/obsidian.png' \
      'Terminal=false' \
      'StartupNotify=true' \
      'StartupWMClass=obsidian' \
      'NoDisplay=false' \
      'Type=Application' \
      'MimeType=x-scheme-handler/obsidian;' \
      'Categories=Office;' \
      > staged/usr/share/applications/obsidian.desktop

RUN set -e; \
    DEB_ROOT="/tmp/deb-obsidian"; \
    mkdir -p "${DEB_ROOT}/DEBIAN"; \
    cp -r staged/. "${DEB_ROOT}/"; \
    SIZE=$(du -sk staged | cut -f1); \
    printf 'Package: obsidian\n'                                >  "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Version: %s\n'         "${VERSION}"                 >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Architecture: %s\n'    "${TARGETARCH}"              >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Maintainer: omakasui <packages@omakasui.org>\n'     >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Installed-Size: %s\n'  "${SIZE}"                    >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Section: utils\n'                                   >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Priority: optional\n'                               >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Homepage: https://obsidian.md\n'                    >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Description: Powerful knowledge base on local Markdown files\n' >> "${DEB_ROOT}/DEBIAN/control"; \
    printf ' Installed to /opt/obsidian. Updates via the built-in auto-updater.\n' >> "${DEB_ROOT}/DEBIAN/control"; \
    mkdir -p /output; \
    fakeroot dpkg-deb --build "${DEB_ROOT}" \
      "/output/obsidian_${VERSION}_${TARGETARCH}.deb"; \
    echo "Built: $(ls -lh /output/obsidian_${VERSION}_${TARGETARCH}.deb)"
