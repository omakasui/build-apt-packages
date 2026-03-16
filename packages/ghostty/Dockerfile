# Builds ghostty terminal from source (Zig).
# Upstream: https://github.com/ghostty-org/ghostty
# Zig is installed via debian.griffo.io which supports both Debian and Ubuntu.
# gtk4-layer-shell is installed from the pre-built dep .deb (depends_on in versions.yml).
# The libgtk4-layer-shell-0.so symlink is produced by the gtk4-layer-shell package itself.

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

# Build dependencies
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    gpg \
    lsb-release \
    build-essential \
    python3-pip \
    debhelper \
    devscripts \
    pandoc \
    libonig-dev \
    libbz2-dev \
    libgtk-4-dev \
    libadwaita-1-dev \
    minisign \
    libxml2-utils \
  && rm -rf /var/lib/apt/lists/*

# Install blueprint-compiler >= 0.16.0 from source.
# The apt version on noble/trixie (0.12.0) is too old for ghostty 1.3.1+.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    meson \
    ninja-build \
    python3-packaging \
  && rm -rf /var/lib/apt/lists/* && \
    git clone --depth 1 --branch 0.16.0 \
      https://gitlab.gnome.org/GNOME/blueprint-compiler.git /tmp/blueprint-compiler && \
    cd /tmp/blueprint-compiler && \
    meson setup --prefix=/usr _build && \
    ninja -C _build install && \
    rm -rf /tmp/blueprint-compiler

# Install gtk4-layer-shell from the pre-built dep .deb.
# The workflow places it in deps/ inside the build context.
COPY deps/ /tmp/deps/
RUN set -e; \
    DEB=$(ls /tmp/deps/gtk4-layer-shell_*_${TARGETARCH}.deb 2>/dev/null | head -1); \
    if [[ -z "$DEB" ]]; then \
      echo "ERROR: gtk4-layer-shell dep not found in deps/"; exit 1; \
    fi; \
    apt-get install -y --no-install-recommends "$DEB"; \
    ldconfig

# Install zig via debian.griffo.io (supports Debian trixie and Ubuntu noble).
RUN curl -sS https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc \
      | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/debian.griffo.io.gpg && \
    echo "deb https://debian.griffo.io/apt $(lsb_release -sc) main" \
      | tee /etc/apt/sources.list.d/debian.griffo.io.list && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends zig && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN git clone --depth 1 --branch "v${VERSION}" \
    https://github.com/ghostty-org/ghostty.git ghostty

WORKDIR /build/ghostty

RUN zig build \
    --summary all \
    --prefix ./zig-out/usr \
    -Doptimize=ReleaseFast \
    -Dcpu=baseline \
    -Dpie=true \
    -Demit-docs \
    -Dversion-string=${VERSION}

# Fix absolute paths left by zig-out in service/desktop/dbus files.
RUN sed -i 's|\./zig-out||g' \
      ./zig-out/usr/share/systemd/user/app-com.mitchellh.ghostty.service \
      ./zig-out/usr/share/applications/com.mitchellh.ghostty.desktop \
      ./zig-out/usr/share/dbus-1/services/com.mitchellh.ghostty.service

# Compress man pages.
RUN gzip -n -9 ./zig-out/usr/share/man/man1/ghostty.1
RUN gzip -n -9 ./zig-out/usr/share/man/man5/ghostty.5

# Fix zsh completions path.
RUN mv ./zig-out/usr/share/zsh/site-functions \
       ./zig-out/usr/share/zsh/vendor-completions

# Remove bundled terminfo (conflicts with system ncurses).
RUN rm -rf ./zig-out/usr/share/terminfo/g || true

# Stage output for assemble-deb.sh
RUN mkdir -p /output/staged && \
    cp -r ./zig-out/usr /output/staged/ && \
    echo "Staged: $(find /output/staged -type f | wc -l) files"