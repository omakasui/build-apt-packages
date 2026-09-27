# Upstream: https://codeberg.org/dnkl/foot

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

# Build dependencies.
# fcft/tllist/wayland-protocols come from the suite: needs fcft >= 3.3.1, wayland-protocols >= 1.41.
# python3: builtin terminfo generation and PGO payload.
# scdoc: man pages.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    dpkg-dev \
    gcc \
    meson \
    ninja-build \
    pkg-config \
    python3 \
    scdoc \
    libfcft-dev \
    libtllist-dev \
    libfontconfig-dev \
    libpixman-1-dev \
    libutf8proc-dev \
    libwayland-dev \
    wayland-protocols \
    libxkbcommon-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN mkdir -p foot && \
    curl -fsSL \
      "https://codeberg.org/dnkl/foot/releases/download/${VERSION}/foot-${VERSION}.tar.gz" \
      -o foot.tar.gz && \
    tar -xzf foot.tar.gz --strip-components=1 -C foot

WORKDIR /build/foot

# Partial PGO: headless, profiles the VT parser only. Adds -O3 and LTO.
# Hardening flags as in Debian's debian/rules.
# nodownload: the bundled .wrap files track upstream master.
# Terminfo comes from ncurses-term, themes from foot-themes.
RUN eval "$(DEB_BUILD_MAINT_OPTIONS='hardening=+all optimize=-lto' \
              DEB_CFLAGS_MAINT_STRIP='-O2' \
              dpkg-buildflags --export=sh)" && \
    mkdir -p bld/release && \
    ./pgo/pgo.sh partial . bld/release \
      --prefix=/usr \
      --wrap-mode=nodownload \
      -Dterminfo=disabled \
      -Ddocs=enabled \
      -Dthemes=false \
      -Dgrapheme-clustering=enabled \
      -Dsystemd-units-dir=/usr/lib/systemd/user

RUN DESTDIR=/output/staged meson install -C bld/release

# Debian layout: compressed man pages and docs, vendor zsh completions, license in debian/copyright.
RUN set -e; \
    STAGED=/output/staged; \
    find "${STAGED}/usr/share/man" -type f -name '*.[0-9]' -exec gzip -n -9 {} +; \
    if [[ -d "${STAGED}/usr/share/zsh/site-functions" ]]; then \
      mkdir -p "${STAGED}/usr/share/zsh"; \
      mv "${STAGED}/usr/share/zsh/site-functions" "${STAGED}/usr/share/zsh/vendor-completions"; \
    fi; \
    rm -f "${STAGED}/usr/share/doc/foot/LICENSE"; \
    gzip -n -9 "${STAGED}/usr/share/doc/foot/README.md"; \
    gzip -n -9 -c "${STAGED}/usr/share/doc/foot/CHANGELOG.md" > "${STAGED}/usr/share/doc/foot/changelog.gz"; \
    rm "${STAGED}/usr/share/doc/foot/CHANGELOG.md"; \
    strip --strip-unneeded "${STAGED}/usr/bin/foot" "${STAGED}/usr/bin/footclient"

RUN echo "Staged: $(find /output/staged -type f | wc -l) files"
