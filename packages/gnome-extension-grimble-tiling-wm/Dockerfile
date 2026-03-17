# Builds gnome-extension-grimble-tiling-wm from source.
# Upstream author: Erwan Lemattre <erwan.lemattre@hotmail.com>
# Extension: https://github.com/erwanlem/grimble-tiling-wm (GPL-2.0)
# This package is built from the omakasui fork:
#   https://github.com/omakasui/grimble-tiling-wm
# The fork may carry omakasui-specific patches; all original copyright
# and licence terms (GPL-2.0) are preserved and distributed with the package.

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION

# Build dependencies.
# nodejs/npm:        compile TypeScript via tsc.
# libglib2.0-bin:    glib-compile-schemas for GSettings.
# gettext:           msgfmt for .po → .mo translation files.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    nodejs \
    npm \
    libglib2.0-bin \
    gettext \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN git clone --depth 1 --branch "v${VERSION}" \
    https://github.com/omakasui/grimble-tiling-wm.git src

WORKDIR /build/src

# Install Node dependencies (tsc + type definitions).
# --legacy-peer-deps avoids duplicate nested installs of @girs/* type definitions
# that would cause TypeScript to see incompatible duplicate types for Gio/GLib.
RUN npm install --legacy-peer-deps && npm dedupe

# Compile TypeScript → JS into dist/.
RUN npx tsc

# Compile GSettings schema.
RUN glib-compile-schemas schemas/

# Compile .po translation files → .mo (mirrors build.sh).
RUN for FILE in translations/*.po; do \
      LANG=$(basename "$FILE" .po); \
      mkdir -p "dist/locale/$LANG/LC_MESSAGES"; \
      msgfmt -c "$FILE" -o "dist/locale/$LANG/LC_MESSAGES/grimble@lmt.github.io.mo"; \
    done

# Assemble extension directory (mirrors build.sh asset copy, minus the zip step).
# modalSearchEntry.js is intentionally excluded per upstream build.sh.
RUN mkdir -p Grimble/schemas && \
    cp metadata.json Grimble/ && \
    cp schemas/org.gnome.shell.extensions.grimble.gschema.xml Grimble/schemas/ && \
    cp -r src/ui Grimble/ && \
    cp src/stylesheet.css Grimble/ && \
    cp -r dist/* Grimble/ && \
    cp -r src/configs Grimble/ && \
    cp LICENSE Grimble/ && \
    rm -f Grimble/modalSearchEntry.js

# Stage output under /usr/local/share (user-level extension path).
RUN mkdir -p /output/staged/usr/local/share/gnome-shell/extensions && \
    cp -r Grimble /output/staged/usr/local/share/gnome-shell/extensions/grimble@lmt.github.io && \
    echo "Staged: $(find /output/staged -type f | wc -l) files"