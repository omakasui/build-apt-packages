# Upstream: https://github.com/ChrisBuilds/terminaltexteffects

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /work

RUN pip3 install \
    --break-system-packages \
    --no-deps \
    --ignore-installed \
    --prefix=/usr \
    --root=/output/staged \
    "terminaltexteffects==${VERSION}"

# Rename site-packages → dist-packages (Debian convention for system Python packages).
# Also normalise the tte script shebang to /usr/bin/python3.
RUN set -e; \
    PYVER="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"; \
    SITE="/output/staged/usr/lib/python${PYVER}/site-packages"; \
    DIST="/output/staged/usr/lib/python3/dist-packages"; \
    if [ -d "$SITE" ]; then \
      mkdir -p "$DIST"; \
      cp -r "$SITE"/. "$DIST/"; \
      rm -rf "/output/staged/usr/lib/python${PYVER}"; \
    fi; \
    if [ -f /output/staged/usr/bin/tte ]; then \
      sed -i 's|^#!.*python.*$|#!/usr/bin/python3|' /output/staged/usr/bin/tte; \
    fi; \
    echo "Staged:"; \
    find /output/staged -type f | sort
