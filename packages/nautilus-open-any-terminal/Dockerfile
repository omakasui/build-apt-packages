# Repackages nautilus-open-any-terminal (renames from upstream nautilus-extension-any-terminal).
# Upstream: https://github.com/Stunkymonkey/nautilus-open-any-terminal
# Release assets: nautilus-open-any-terminal_<version>_all.deb

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    dpkg-dev \
  && rm -rf /var/lib/apt/lists/*

ARG VERSION

WORKDIR /work

RUN set -e; \
    DEB="nautilus-extension-any-terminal_${VERSION}-1_all.deb"; \
    URL="https://github.com/Stunkymonkey/nautilus-open-any-terminal/releases/download/${VERSION}/${DEB}"; \
    \
    echo "Downloading ${URL}..."; \
    curl -fsSL "${URL}" -o "${DEB}"; \
    \
    mkdir -p extracted; \
    dpkg-deb -R "${DEB}" extracted/; \
    \
    CTRL="extracted/DEBIAN/control"; \
    sed -i "s/^Package: nautilus-extension-any-terminal$/Package: nautilus-open-any-terminal/" "$CTRL"; \
    \
    # Remove conffiles if empty or containing blank lines — dpkg-deb rejects non-absolute paths. \
    if [ -f extracted/DEBIAN/conffiles ]; then \
      sed -i '/^[[:space:]]*$/d' extracted/DEBIAN/conffiles; \
      [ ! -s extracted/DEBIAN/conffiles ] && rm extracted/DEBIAN/conffiles; \
    fi; \
    \
    grep -q "^Conflicts:" "$CTRL" || printf "Conflicts: nautilus-extension-any-terminal\n" >> "$CTRL"; \
    grep -q "^Replaces:"  "$CTRL" || printf "Replaces: nautilus-extension-any-terminal\n"  >> "$CTRL"; \
    grep -q "^Provides:"  "$CTRL" || printf "Provides: nautilus-extension-any-terminal\n"  >> "$CTRL"; \
    \
    mkdir -p /output; \
    dpkg-deb -b extracted/ "/output/nautilus-open-any-terminal_${VERSION}_all.deb"; \
    echo "Built: $(ls -lh /output/)"