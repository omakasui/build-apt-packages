# Upstream: https://github.com/Alexays/Waybar

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    meson \
    ninja-build \
    pkg-config \
    gcc \
    g++ \
    scdoc \
    wayland-protocols \
    gobject-introspection \
    libdbusmenu-gtk3-dev \
    libevdev-dev \
    libfmt-dev \
    libgirepository1.0-dev \
    libgtk-3-dev \
    libgtkmm-3.0-dev \
    libinput-dev \
    libjsoncpp-dev \
    libmpdclient-dev \
    libnl-3-dev \
    libnl-genl-3-dev \
    libpulse-dev \
    libsigc++-2.0-dev \
    libspdlog-dev \
    libupower-glib-dev \
    libwayland-dev \
    libxkbregistry-dev \
    libgtk-layer-shell-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN curl -fsSL \
    "https://github.com/Alexays/Waybar/releases/download/${VERSION}/waybar-${VERSION}.tar.gz" \
    -o waybar.tar.gz && \
    tar -xzf waybar.tar.gz && \
    mv waybar-${VERSION} waybar

WORKDIR /build/waybar

RUN meson setup build \
      --prefix=/usr \
      -Dexperimental=true \
      -Dtests=disabled && \
    ninja -C build && \
    DESTDIR=/output/staged ninja -C build install && \
    echo "Staged: $(find /output/staged -type f | wc -l) files"