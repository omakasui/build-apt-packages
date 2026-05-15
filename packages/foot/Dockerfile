# Upstream: https://codeberg.org/dnkl/foot

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

# Build dependencies.
# meson/ninja-build: build system.
# libfontconfig1-dev/libfreetype6-dev: font rendering.
# libpixman-1-dev: pixel manipulation (required by fcft subproject).
# libwayland-dev/wayland-protocols: Wayland compositor protocol.
# libxkbcommon-dev: keyboard input handling.
# libutf8proc-dev: grapheme clustering support.
# libutempter-dev: utmp/wtmp login logging support.
# ncurses-bin: provides `tic` to build terminfo definitions.
# scdoc: generate man pages.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    meson \
    ninja-build \
    pkg-config \
    gcc \
    libfontconfig1-dev \
    libfreetype6-dev \
    libpixman-1-dev \
    libwayland-dev \
    wayland-protocols \
    libxkbcommon-dev \
    libutf8proc-dev \
    libutempter-dev \
    ncurses-bin \
    scdoc \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Download and extract the official release tarball.
RUN mkdir -p foot && \
    curl -fsSL \
      "https://codeberg.org/dnkl/foot/releases/download/${VERSION}/foot-${VERSION}.tar.gz" \
      -o foot.tar.gz && \
    tar -xzf foot.tar.gz --strip-components=1 -C foot

WORKDIR /build/foot

# Build a release binary with LTO.
# fcft and tllist are built as meson subprojects if not found as system libraries.
# -Dtests=false skips the test suite to speed up the build.
RUN meson setup bld/release \
      --buildtype=release \
      --prefix=/usr \
      -Db_lto=true \
      -Dtests=false && \
    ninja -C bld/release && \
    DESTDIR=/output/staged ninja -C bld/release install && \
    echo "Staged: $(du -sh /output/staged)"

# Stage maintainer scripts.
RUN mkdir -p /output/staged/DEBIAN
COPY preinst  /output/staged/DEBIAN/preinst
COPY postinst /output/staged/DEBIAN/postinst
COPY postrm   /output/staged/DEBIAN/postrm
RUN chmod 0755 /output/staged/DEBIAN/preinst \
               /output/staged/DEBIAN/postinst \
               /output/staged/DEBIAN/postrm
