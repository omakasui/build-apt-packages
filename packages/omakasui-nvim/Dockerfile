# Builds a pre-cached LazyVim configuration (omakasui edition).
# Mirrors the omarchy-nvim PKGBUILD logic adapted for Debian/Ubuntu.
# Upstream LazyVim starter: https://github.com/LazyVim/starter

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

# Install latest stable neovim from GitHub releases (distro packages are often outdated).
ARG TARGETARCH
RUN set -e; \
    case "${TARGETARCH}" in \
      amd64) NVIM_ARCH="linux-x86_64" ;; \
      arm64) NVIM_ARCH="linux-arm64"  ;; \
      *)     echo "Unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL \
      "https://github.com/neovim/neovim/releases/latest/download/nvim-${NVIM_ARCH}.tar.gz" \
      -o /tmp/nvim.tar.gz; \
    tar -xzf /tmp/nvim.tar.gz -C /usr/local --strip-components=1; \
    rm /tmp/nvim.tar.gz; \
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