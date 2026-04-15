# Builds pre-cached LazyVim configurations for all omakasui project variants.
# Upstream LazyVim starter: https://github.com/LazyVim/starter

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    nodejs \
    npm \
    unzip \
    build-essential \
    fakeroot \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g tree-sitter-cli

COPY deps/ /tmp/deps/
RUN set -e; \
    DEB=$(ls /tmp/deps/nvim_*_${TARGETARCH}.deb 2>/dev/null | head -1); \
    if [[ -z "$DEB" ]]; then \
      echo "ERROR: nvim dep not found in deps/"; exit 1; \
    fi; \
    apt-get install -y --no-install-recommends "$DEB"; \
    nvim --version

WORKDIR /build

COPY lua/                 lua/
COPY plugin/              plugin/
COPY lazyvim.json         lazyvim.json
COPY setup-nvim.template  setup-nvim.template

# Download LazyVim starter once — shared across all three variants.
RUN curl -fsSL \
    "https://github.com/LazyVim/starter/archive/refs/heads/main.tar.gz" \
    -o starter.tar.gz && \
    tar -xzf starter.tar.gz

ENV HOME=/build/build-home
ENV XDG_CONFIG_HOME=/build/build-home/.config
ENV XDG_DATA_HOME=/build/build-home/.local/share
ENV XDG_STATE_HOME=/build/build-home/.local/state
ENV XDG_CACHE_HOME=/build/build-home/.cache

RUN mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"

RUN cp -r starter-main "$XDG_CONFIG_HOME/nvim" && \
    rm -rf "$XDG_CONFIG_HOME/nvim/.git"

RUN cp -r lua/    "$XDG_CONFIG_HOME/nvim/lua/"  && \
    cp -r plugin/ "$XDG_CONFIG_HOME/nvim/plugin/" && \
    cp lazyvim.json "$XDG_CONFIG_HOME/nvim/lazyvim.json" && \
    echo "vim.opt.relativenumber = false" >> "$XDG_CONFIG_HOME/nvim/lua/config/options.lua"

# Pre-cache plugins once — shared by all three variants.
RUN nvim --headless "+Lazy! sync" "+qa!" || true

# Build all three .deb files.
RUN set -e; \
    mkdir -p /output; \
    for PROJECT in omakasui omakub omadeb omari; do \
      PKG_NAME="${PROJECT}-nvim"; \
      SHARE_DIR="/usr/share/${PKG_NAME}"; \
      STAGED="/tmp/staged-${PROJECT}"; \
      \
      # Stage config and data. \
      mkdir -p "${STAGED}${SHARE_DIR}"; \
      cp -a "$XDG_CONFIG_HOME/nvim" "${STAGED}${SHARE_DIR}/config"; \
      cp -a "$XDG_DATA_HOME/nvim"   "${STAGED}${SHARE_DIR}/data"; \
      rm -rf "${STAGED}${SHARE_DIR}/data/site/"*; \
      mkdir -p "${STAGED}${SHARE_DIR}/data/site"; \
      chmod -R 755 "${STAGED}${SHARE_DIR}"; \
      find "${STAGED}${SHARE_DIR}" -type f -exec chmod 644 {} \;; \
      \
      # Instantiate setup script from template via sed. \
      mkdir -p "${STAGED}/usr/bin"; \
      SETUP="${STAGED}/usr/bin/${PROJECT}-setup-nvim"; \
      sed \
        -e "s|{{PROJECT}}|${PROJECT}|g" \
        -e "s|{{PKG_NAME}}|${PKG_NAME}|g" \
        /build/setup-nvim.template > "$SETUP"; \
      chmod 755 "$SETUP"; \
      \
      # Write DEBIAN/control. \
      DEB_ROOT="/tmp/deb-${PROJECT}"; \
      mkdir -p "${DEB_ROOT}/DEBIAN"; \
      cp -r "${STAGED}/." "${DEB_ROOT}/"; \
      SIZE=$(du -sk "$STAGED" | cut -f1); \
      printf "Package: %s\nVersion: %s\nArchitecture: all\n" \
        "${PKG_NAME}" "${VERSION}" > "${DEB_ROOT}/DEBIAN/control"; \
      printf "Maintainer: omakasui <packages@omakasui.org>\n" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf "Installed-Size: %s\n" "${SIZE}" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf "Depends: nvim, git, gum\n" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf "Section: editors\nPriority: optional\n" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf "Homepage: https://github.com/LazyVim/LazyVim\n" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf "Description: Pre-built LazyVim configuration for %s\n" "${PROJECT}" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf " Installs pre-cached config and plugins to %s.\n" "${SHARE_DIR}" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf " Run %s-setup-nvim to activate for the current user.\n" "${PROJECT}" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      \
      fakeroot dpkg-deb --build "${DEB_ROOT}" \
        "/output/${PKG_NAME}_${VERSION}_all.deb"; \
      echo "Built: $(ls -lh /output/${PKG_NAME}_${VERSION}_all.deb)"; \
    done