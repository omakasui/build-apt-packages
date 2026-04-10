# Packages the upstream Zen Browser tarball into a .deb.
# Installs the browser bundle to /opt/zen, adds a symlink at /usr/bin/zen,
# and installs a .desktop file for GNOME/application menus.
# Upstream: https://github.com/zen-browser/desktop
#
# Asset naming convention:
#   amd64 → zen.linux-x86_64.tar.xz
#   arm64 → zen.linux-aarch64.tar.xz

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
    dpkg-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN set -e; \
    case "${TARGETARCH}" in \
      amd64)  UPSTREAM_ARCH="x86_64"  ;; \
      arm64)  UPSTREAM_ARCH="aarch64" ;; \
      *)      echo "ERROR: unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL \
      "https://github.com/zen-browser/desktop/releases/download/${VERSION}/zen.linux-${UPSTREAM_ARCH}.tar.xz" \
      -o zen.tar.xz; \
    tar -xJf zen.tar.xz

RUN set -e; \
    mkdir -p staged/opt/zen; \
    cp -r zen/. staged/opt/zen/; \
    chmod -R 755 staged/opt/zen; \
    mkdir -p staged/usr/bin; \
    ln -sf /opt/zen/zen staged/usr/bin/zen; \
    mkdir -p staged/usr/share/applications; \
    printf '%s\n' \
      '[Desktop Entry]' \
      'Name=Zen Browser' \
      'Comment=Experience tranquillity while browsing the web without people tracking you!' \
      'Keywords=web;browser;internet' \
      'Exec=/opt/zen/zen %u' \
      'Icon=/opt/zen/browser/chrome/icons/default/default128.png' \
      'Terminal=false' \
      'StartupNotify=true' \
      'StartupWMClass=zen' \
      'NoDisplay=false' \
      'Type=Application' \
      'MimeType=text/html;text/xml;application/xhtml+xml;application/vnd.mozilla.xul+xml;text/mml;x-scheme-handler/http;x-scheme-handler/https;' \
      'Categories=Network;WebBrowser;' \
      'Actions=new-window;new-blank-window;new-private-window;profile-manager-window;' \
      '' \
      '[Desktop Action new-window]' \
      'Name=Open a New Window' \
      'Exec=/opt/zen/zen --new-window %u' \
      '' \
      '[Desktop Action new-blank-window]' \
      'Name=Open a New Blank Window' \
      'Exec=/opt/zen/zen --blank-window %u' \
      '' \
      '[Desktop Action new-private-window]' \
      'Name=Open a New Private Window' \
      'Exec=/opt/zen/zen --private-window %u' \
      '' \
      '[Desktop Action profile-manager-window]' \
      'Name=Open the Profile Manager' \
      'Exec=/opt/zen/zen --ProfileManager' \
      > staged/usr/share/applications/zen-browser.desktop

RUN set -e; \
    DEB_ROOT="/tmp/deb-zen"; \
    mkdir -p "${DEB_ROOT}/DEBIAN"; \
    cp -r staged/. "${DEB_ROOT}/"; \
    SIZE=$(du -sk staged | cut -f1); \
    printf 'Package: zen-browser\n'                             >  "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Version: %s\n'         "${VERSION}"                >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Architecture: %s\n'    "${TARGETARCH}"             >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Maintainer: omakasui <packages@omakasui.org>\n'    >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Installed-Size: %s\n'  "${SIZE}"                   >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Section: web\n'                                    >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Priority: optional\n'                              >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Homepage: https://zen-browser.app\n'               >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Description: Privacy-focused Firefox-based browser\n' >> "${DEB_ROOT}/DEBIAN/control"; \
    printf ' Features vertical tabs, workspaces and tab splitting.\n' >> "${DEB_ROOT}/DEBIAN/control"; \
    printf ' Installed to /opt/zen. Updates via the built-in auto-updater.\n' >> "${DEB_ROOT}/DEBIAN/control"; \
    mkdir -p /output; \
    fakeroot dpkg-deb --build "${DEB_ROOT}" \
      "/output/zen-browser_${VERSION}_${TARGETARCH}.deb"; \
    echo "Built: $(ls -lh /output/zen-browser_${VERSION}_${TARGETARCH}.deb)"