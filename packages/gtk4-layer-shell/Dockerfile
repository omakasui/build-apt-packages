# Produces libgtk4-layer-shell.so + GObject Introspection typelib.
# Upstream: https://github.com/wmww/gtk4-layer-shell

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    meson \
    ninja-build \
    pkg-config \
    gcc \
    libwayland-dev \
    wayland-protocols \
    libgtk-4-dev \
    gobject-introspection \
    libgirepository1.0-dev \
    gtk-doc-tools \
    python3 \
    valac \
  && rm -rf /var/lib/apt/lists/*

ARG VERSION
ARG TARGETARCH

WORKDIR /build

RUN curl -fsSL \
    "https://github.com/wmww/gtk4-layer-shell/archive/refs/tags/v${VERSION}.tar.gz" \
    -o src.tar.gz && \
    tar -xzf src.tar.gz && \
    mv "gtk4-layer-shell-${VERSION}" src

RUN meson setup \
      --prefix=/usr \
      --buildtype=release \
      -Dexamples=false \
      -Ddocs=false \
      -Dtests=false \
      -Dsmoke-tests=false \
      -Dintrospection=true \
      -Dvapi=false \
      build src

RUN ninja -C build

RUN DESTDIR=/output/staged ninja -C build install

# Verify expected files are present.
RUN set -e; \
    ls -lh /output/staged/usr/lib/*/libgtk4-layer-shell.so* 2>/dev/null || \
    ls -lh /output/staged/usr/lib/libgtk4-layer-shell.so*; \
    find /output/staged -name "Gtk4LayerShell*.typelib"; \
    echo "Staged: $(du -sh /output/staged)"

# Add libgtk4-layer-shell-0.so symlink — some consumers (e.g. ghostty) look
# for this name convention instead of the plain libgtk4-layer-shell.so.
RUN LIBDIR=$(find /output/staged/usr/lib -maxdepth 1 -mindepth 1 -type d | head -1); \
    [ -z "$LIBDIR" ] && LIBDIR="/output/staged/usr/lib"; \
    ln -sf "${LIBDIR##/output/staged}/libgtk4-layer-shell.so" \
           "${LIBDIR}/libgtk4-layer-shell-0.so" && \
    echo "Symlinked: ${LIBDIR}/libgtk4-layer-shell-0.so"