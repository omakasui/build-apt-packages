# Builds a pre-cached LazyVim configuration.
# Mirrors the omarchy-nvim PKGBUILD logic adapted for Debian/Ubuntu.
# Upstream LazyVim starter: https://github.com/LazyVim/starter
# Depends on the nvim package for the neovim binary.

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    nodejs \
    npm \
    unzip \
    build-essential \
  && rm -rf /var/lib/apt/lists/*

# Install tree-sitter-cli via npm globally.
RUN npm install -g tree-sitter-cli

# Install nvim from the pre-built dep (built by the nvim package in this repo).
ARG TARGETARCH
COPY deps/ /tmp/deps/
RUN set -e; \
    DEB=$(ls /tmp/deps/nvim_*_${TARGETARCH}.deb 2>/dev/null | head -1); \
    if [[ -z "$DEB" ]]; then \
      echo "ERROR: nvim dep not found in deps/"; exit 1; \
    fi; \
    apt-get install -y --no-install-recommends "$DEB"; \
    nvim --version

ARG VERSION

WORKDIR /build

# Copy all custom config files first.
COPY lua/            lua/
COPY plugin/         plugin/
COPY lazyvim.json    lazyvim.json
COPY omakasui-nvim-setup omakasui-nvim-setup

# Download LazyVim starter.
RUN curl -fsSL \
    "https://github.com/LazyVim/starter/archive/refs/heads/main.tar.gz" \
    -o starter.tar.gz && \
    tar -xzf starter.tar.gz

# Set up isolated XDG environment.
ENV HOME=/build/build-home
ENV XDG_CONFIG_HOME=/build/build-home/.config
ENV XDG_DATA_HOME=/build/build-home/.local/share
ENV XDG_STATE_HOME=/build/build-home/.local/state
ENV XDG_CACHE_HOME=/build/build-home/.cache

RUN mkdir -p \
    "$XDG_CONFIG_HOME" \
    "$XDG_DATA_HOME" \
    "$XDG_STATE_HOME" \
    "$XDG_CACHE_HOME"

# Copy LazyVim starter into config.
RUN cp -r starter-main "$XDG_CONFIG_HOME/nvim" && \
    rm -rf "$XDG_CONFIG_HOME/nvim/.git"

# Overlay omakasui custom configs.
RUN cp -r lua/   "$XDG_CONFIG_HOME/nvim/lua/" && \
    cp -r plugin/ "$XDG_CONFIG_HOME/nvim/plugin/" && \
    cp lazyvim.json "$XDG_CONFIG_HOME/nvim/lazyvim.json" && \
    echo "vim.opt.relativenumber = false" >> "$XDG_CONFIG_HOME/nvim/lua/config/options.lua"

# Pre-cache all plugins headless.
RUN nvim --headless "+Lazy! sync" "+qa!" || true

# Stage output.
RUN set -e; \
    mkdir -p /output/staged/usr/share/omakasui-nvim; \
    cp -a "$XDG_CONFIG_HOME/nvim" /output/staged/usr/share/omakasui-nvim/config; \
    cp -a "$XDG_DATA_HOME/nvim"   /output/staged/usr/share/omakasui-nvim/data; \
    \
    # Remove site/ contents but keep the directory (mirrors PKGBUILD). \
    rm -rf /output/staged/usr/share/omakasui-nvim/data/site/*; \
    mkdir -p /output/staged/usr/share/omakasui-nvim/data/site; \
    \
    # Fix permissions. \
    chmod -R 755 /output/staged/usr/share/omakasui-nvim; \
    find /output/staged/usr/share/omakasui-nvim -type f -exec chmod 644 {} \;; \
    \
    # Install setup script. \
    install -Dm755 omakasui-nvim-setup \
      /output/staged/usr/bin/omakasui-nvim-setup; \
    \
    echo "Staged: $(du -sh /output/staged)"