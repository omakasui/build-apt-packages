# Upstream: https://github.com/abenz1267/walker

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    pkg-config \
    build-essential \
    libgtk-4-dev \
    libcairo2-dev \
    libpoppler-glib-dev \
    protobuf-compiler \
    libglib2.0-dev \
  && rm -rf /var/lib/apt/lists/*

# Install rustup stable.
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
ENV PATH="/root/.cargo/bin:${PATH}"

ARG VERSION
ARG TARGETARCH

# Install libgtk4-layer-shell0 from the pre-built dep .deb.
# The workflow places it in deps/ inside the build context.
COPY deps/ /tmp/deps/
RUN set -e; \
    DEB=$(ls /tmp/deps/libgtk4-layer-shell0_*_${TARGETARCH}.deb 2>/dev/null | head -1); \
    if [[ -z "$DEB" ]]; then \
      echo "ERROR: libgtk4-layer-shell0 dep not found in deps/"; exit 1; \
    fi; \
    apt-get install -y --no-install-recommends "$DEB"; \
    ldconfig

WORKDIR /build

RUN curl -fsSL \
    "https://github.com/abenz1267/walker/archive/refs/tags/v${VERSION}.tar.gz" \
    -o src.tar.gz && \
    tar -xzf src.tar.gz && \
    mv "walker-${VERSION}" walker

WORKDIR /build/walker

RUN cargo build --release

# Stage binary.
RUN mkdir -p /output/staged/usr/bin && \
    install -m 0755 target/release/walker /output/staged/usr/bin/walker

# Stage default config and themes from resources/.
RUN set -e; \
    mkdir -p /output/staged/etc/xdg/walker/themes/default; \
    install -m 0644 resources/config.toml \
      /output/staged/etc/xdg/walker/; \
    for f in \
      item.xml item_calc.xml item_clipboard.xml item_dmenu.xml \
      item_files.xml item_providerlist.xml item_symbols.xml \
      item_symbols_grid.xml item_todo.xml item_unicode.xml \
      item_archlinuxpkgs.xml item_dnfpackages.xml \
      layout.xml keybind.xml preview.xml style.css; do \
        src="resources/themes/default/${f}"; \
        [ -f "$src" ] && install -m 0644 "$src" \
          /output/staged/etc/xdg/walker/themes/default/ || true; \
    done; \
    echo "Staged: $(ls -lh /output/staged/usr/bin/walker)"