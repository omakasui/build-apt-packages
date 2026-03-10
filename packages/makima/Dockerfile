# Builds makima from source using the Rust toolchain.
# Upstream: https://github.com/cyber-sushi/makima

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    build-essential \
    pkg-config \
    libudev-dev \
    git \
  && rm -rf /var/lib/apt/lists/*

# Install Rust via rustup (non-interactive, stable channel).
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"

ARG VERSION

WORKDIR /work

RUN set -e; \
    git clone --depth 1 --branch "v${VERSION}" \
      https://github.com/cyber-sushi/makima makima; \
    cd makima; \
    \
    cargo build --release; \
    \
    # Stage binary. \
    mkdir -p /output/staged/usr/bin; \
    install -m 0755 target/release/makima /output/staged/usr/bin/makima; \
    \
    # Stage systemd system unit. \
    mkdir -p /output/staged/lib/systemd/system; \
    install -m 0644 makima.service /output/staged/lib/systemd/system/makima.service; \
    \
    # Stage udev rules. \
    if [ -f 50-makima.rules ]; then \
      mkdir -p /output/staged/usr/lib/udev/rules.d; \
      install -m 0644 50-makima.rules \
        /output/staged/usr/lib/udev/rules.d/50-makima.rules; \
    fi; \
    \
    # Stage example configs. \
    if [ -d config ]; then \
      mkdir -p /output/staged/usr/share/doc/makima/examples; \
      cp -r config/. /output/staged/usr/share/doc/makima/examples/; \
    fi; \
    \
    echo "Build complete: $(ls -lh /output/staged/usr/bin/makima)"

# Stage postinst.
RUN mkdir -p /output/staged/DEBIAN
COPY postinst /output/staged/DEBIAN/postinst
RUN chmod 0755 /output/staged/DEBIAN/postinst