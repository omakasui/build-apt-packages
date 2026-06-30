# Installs the browser bundle to /opt/zen, adds a symlink at /usr/bin/zen,
# and installs a .desktop file for GNOME/application menus.
# Upstream: https://github.com/zen-browser/desktop

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

# Copy staged tree to output for external assembly by build.sh.
RUN mkdir -p /output/staged && cp -r staged/. /output/staged/

RUN echo "Staged: $(find /output/staged -type f | wc -l) files"