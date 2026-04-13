# Upstream: https://github.com/alacritty/alacritty

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

# Build dependencies.
# cmake/pkg-config: required by some Rust crates.
# libfontconfig-dev/libfreetype-dev: font rendering.
# libxcb-*/libxkbcommon-dev: X11/Wayland input and windowing.
# scdoc: generate man pages.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    cmake \
    pkg-config \
    build-essential \
    libfontconfig1-dev \
    libfreetype6-dev \
    libxcb-render0-dev \
    libxcb-shape0-dev \
    libxcb-xfixes0-dev \
    libxkbcommon-dev \
    scdoc \
  && rm -rf /var/lib/apt/lists/*

# Install Rust via rustup (stable toolchain).
ENV CARGO_HOME=/usr/local/cargo
ENV RUSTUP_HOME=/usr/local/rustup
ENV PATH=/usr/local/cargo/bin:$PATH
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal

WORKDIR /build

RUN git clone --depth 1 --branch "v${VERSION}" \
    https://github.com/alacritty/alacritty.git src

WORKDIR /build/src

# Build release binary.
RUN cargo build --release --locked

# Build man pages via scdoc.
RUN scdoc < extra/man/alacritty.1.scd     | gzip -c > /tmp/alacritty.1.gz && \
    scdoc < extra/man/alacritty.5.scd     | gzip -c > /tmp/alacritty.5.gz && \
    scdoc < extra/man/alacritty-msg.1.scd | gzip -c > /tmp/alacritty-msg.1.gz && \
    scdoc < extra/man/alacritty-bindings.5.scd | gzip -c > /tmp/alacritty-bindings.5.gz || true

# Stage output.
RUN set -e; \
    install -Dm755 target/release/alacritty \
      /output/staged/usr/bin/alacritty; \
    \
    # Desktop entry and icons. \
    install -Dm644 extra/linux/Alacritty.desktop \
      /output/staged/usr/share/applications/Alacritty.desktop; \
    install -Dm644 extra/logo/alacritty-term.svg \
      /output/staged/usr/share/pixmaps/Alacritty.svg; \
    \
    # Man pages. \
    install -Dm644 /tmp/alacritty.1.gz \
      /output/staged/usr/share/man/man1/alacritty.1.gz; \
    install -Dm644 /tmp/alacritty-msg.1.gz \
      /output/staged/usr/share/man/man1/alacritty-msg.1.gz; \
    install -Dm644 /tmp/alacritty.5.gz \
      /output/staged/usr/share/man/man5/alacritty.5.gz; \
    install -Dm644 /tmp/alacritty-bindings.5.gz \
      /output/staged/usr/share/man/man5/alacritty-bindings.5.gz || true; \
    \
    # Shell completions. \
    install -Dm644 extra/completions/alacritty.bash \
      /output/staged/usr/share/bash-completion/completions/alacritty; \
    install -Dm644 extra/completions/_alacritty \
      /output/staged/usr/share/zsh/vendor-completions/_alacritty; \
    install -Dm644 extra/completions/alacritty.fish \
      /output/staged/usr/share/fish/vendor_completions.d/alacritty.fish; \
    \
    echo "Staged: $(du -sh /output/staged)"

# Stage maintainer scripts.
RUN mkdir -p /output/staged/DEBIAN
COPY preinst /output/staged/DEBIAN/preinst
COPY postinst /output/staged/DEBIAN/postinst
COPY postrm   /output/staged/DEBIAN/postrm
RUN chmod 0755 /output/staged/DEBIAN/preinst \
               /output/staged/DEBIAN/postinst \
               /output/staged/DEBIAN/postrm