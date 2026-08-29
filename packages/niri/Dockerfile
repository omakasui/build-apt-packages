# Upstream: https://github.com/niri-wm/niri
#
# Files installed per the packaging wiki:
#   /usr/bin/niri
#   /usr/bin/niri-session
#   /usr/lib/systemd/user/niri.service
#   /usr/lib/systemd/user/niri-shutdown.target
#   /usr/share/wayland-sessions/niri.desktop
#   /usr/share/xdg-desktop-portal/niri-portals.conf
#   shell completions
#   default-config.kdl + README.md under /usr/share/doc/niri/

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG SUITE
ARG TARGETARCH

# Build dependencies.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    gcc \
    clang \
    libclang-dev \
    pkg-config \
    dpkg-dev \
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
    libglib2.0-dev \
    libcairo2-dev \
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

# No .git in the tarball, so build.rs can't resolve the commit hash. Set it here or the build fails.
RUN export NIRI_BUILD_VERSION_STRING="${VERSION}-1+${SUITE}" && \
    cargo build --release --locked \
      --no-default-features \
      --features dbus,systemd,xdp-gnome-screencast

# Stage binary.
RUN install -Dm755 target/release/niri /output/staged/usr/bin/niri && \
    strip --strip-debug /output/staged/usr/bin/niri

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

# default-config.kdl is embedded in the binary; ship a readable copy.
RUN install -Dm644 resources/default-config.kdl \
      /output/staged/usr/share/doc/niri/default-config.kdl && \
    install -Dm644 README.md /output/staged/usr/share/doc/niri/README.md

# Stage shell completions.
RUN NIRI=/output/staged/usr/bin/niri; \
    "$NIRI" completions bash | install -Dm644 /dev/stdin \
      /output/staged/usr/share/bash-completion/completions/niri && \
    "$NIRI" completions zsh  | install -Dm644 /dev/stdin \
      /output/staged/usr/share/zsh/vendor-completions/_niri && \
    "$NIRI" completions fish | install -Dm644 /dev/stdin \
      /output/staged/usr/share/fish/vendor_completions.d/niri.fish

RUN echo "Staged: $(find /output/staged -type f)"