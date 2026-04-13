# Upstream: https://github.com/niri-wm/niri
#
# Files installed per the packaging wiki:
#   /usr/bin/niri
#   /usr/lib/systemd/user/niri.service
#   /usr/lib/systemd/user/niri-session.service
#   /usr/share/wayland-sessions/niri.desktop
#   /usr/share/xdg-desktop-portal/niri-portals.conf

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

# Build dependencies.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    gcc \
    clang \
    pkg-config \
    libudev-dev \
    libgbm-dev \
    libxkbcommon-dev \
    libegl1-mesa-dev \
    libwayland-dev \
    libinput-dev \
    libdbus-1-dev \
    libsystemd-dev \
    libseat-dev \
    libpipewire-0.3-dev \
    libpango1.0-dev \
    libdisplay-info-dev \
  && rm -rf /var/lib/apt/lists/*

# Install Rust via rustup (stable, MSRV >= 1.85).
ENV RUSTUP_HOME=/opt/rustup
ENV CARGO_HOME=/opt/cargo
ENV PATH="${CARGO_HOME}/bin:${PATH}"

RUN curl -fsSL https://sh.rustup.rs | \
    sh -s -- -y --no-modify-path --profile minimal --default-toolchain stable && \
    rustc --version && cargo --version

WORKDIR /build

RUN curl -fsSL \
    "https://github.com/niri-wm/niri/archive/refs/tags/v${VERSION}.tar.gz" \
    -o niri.tar.gz && \
    tar -xzf niri.tar.gz && \
    mv niri-${VERSION} niri

WORKDIR /build/niri

# Build release binary. NIRI_BUILD_COMMIT is set to avoid "unknown commit".
RUN export NIRI_BUILD_VERSION_STRING="${VERSION}" && \
    cargo build --release --locked 2>&1 | tail -5

# Stage binary.
RUN install -Dm755 target/release/niri /output/staged/usr/bin/niri

# Stage niri-session wrapper script.
RUN install -Dm755 resources/niri-session \
      /output/staged/usr/bin/niri-session

# Stage systemd units.
RUN install -Dm644 resources/niri.service \
      /output/staged/usr/lib/systemd/user/niri.service && \
    install -Dm644 resources/niri-shutdown.target \
      /output/staged/usr/lib/systemd/user/niri-shutdown.target

# Stage wayland session desktop entry.
RUN install -Dm644 resources/niri.desktop \
      /output/staged/usr/share/wayland-sessions/niri.desktop

# Stage xdg-desktop-portal config.
RUN install -Dm644 resources/niri-portals.conf \
      /output/staged/usr/share/xdg-desktop-portal/niri-portals.conf

RUN echo "Staged: $(find /output/staged -type f)"