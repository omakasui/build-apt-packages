# =============================================================================
# Build environment for rofi 2.0.0 on Debian Trixie.
#
# Build args:
#   BASE_IMAGE   — base Docker image (debian:trixie)
#   ROFI_VERSION — version to build (e.g. 2.0.0)
#
# Custom dependencies (if any) are placed in packages/rofi/deps/ by the CI
# and COPYed here. They are installed inside the container before the build
# so they are available at compile and link time.
#
# Output: /output/staged/ — installed file tree (usr/, etc.)
# =============================================================================

ARG BASE_IMAGE=debian:trixie
FROM ${BASE_IMAGE}

ARG ROFI_VERSION=2.0.0

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    meson \
    ninja-build \
    pkg-config \
    wget \
    xz-utils \
    libxcb-xkb-dev \
    libxcb-randr0-dev \
    libxcb-xinerama0-dev \
    libxcb-util-dev \
    libxcb-ewmh-dev \
    libxcb-icccm4-dev \
    libxcb-cursor-dev \
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    libwayland-dev \
    wayland-protocols \
    libglib2.0-dev \
    libcairo2-dev \
    libpango1.0-dev \
    libgdk-pixbuf-2.0-dev \
    libstartup-notification0-dev \
    libxcb-imdkit-dev \
    dpkg-dev \
    fakeroot \
    && rm -rf /var/lib/apt/lists/*

# Install custom dependency .deb files if present.
# For rofi this is currently unused, but the structure is here for future packages.
COPY deps/ /tmp/deps/
RUN if ls /tmp/deps/*.deb >/dev/null 2>&1; then \
      apt-get update && \
      apt-get install -y --no-install-recommends /tmp/deps/*.deb && \
      rm -rf /tmp/deps /var/lib/apt/lists/*; \
    fi

RUN mkdir -p /output/staged /build
WORKDIR /build

RUN wget -q \
    "https://github.com/davatorium/rofi/releases/download/${ROFI_VERSION}/rofi-${ROFI_VERSION}.tar.xz" \
    -O rofi.tar.xz \
    && tar -xf rofi.tar.xz \
    && rm rofi.tar.xz

RUN cd rofi-${ROFI_VERSION} \
    && meson setup build \
        --prefix=/usr \
        --buildtype=release \
        -Dcheck=false \
    && ninja -C build \
    && DESTDIR=/output/staged ninja -C build install

CMD ["echo", "Build complete"]