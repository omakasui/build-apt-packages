# Builds uwsm from source using the upstream debian/ packaging.
# Upstream: https://github.com/Vladimir-csp/uwsm

ARG BASE_IMAGE=debian:trixie-slim
FROM ${BASE_IMAGE}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    debhelper \
    dh-python \
    python3-all \
    meson \
    ninja-build \
    cmake \
    pkgconf \
    scdoc \
    python3-dbus \
    python3-xdg \
    curl \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

ARG VERSION

WORKDIR /work

RUN set -e; \
    mkdir -p /output; \
    \
    # Download source tarball (includes upstream debian/ dir). \
    URL="https://github.com/Vladimir-csp/uwsm/archive/refs/tags/v${VERSION}.tar.gz"; \
    curl -fsSL "$URL" -o "uwsm_${VERSION}.orig.tar.gz"; \
    tar -xzf "uwsm_${VERSION}.orig.tar.gz"; \
    mv "uwsm-${VERSION}" uwsm; \
    cd uwsm; \
    \
    # Rename package to omakasui-uwsm and add Conflicts/Replaces/Provides. \
    sed -i 's/^Package: uwsm$/Package: omakasui-uwsm/' debian/control; \
    printf 'Conflicts: uwsm\nReplaces: uwsm\nProvides: uwsm\n' >> debian/control; \
    \
    # Patch Architecture to "all" (package is pure Python/shell, no compiled code). \
    sed -i 's/^Architecture: any$/Architecture: all/' debian/control; \
    \
    # Replace Ubuntu-only util-linux-extra with util-linux (Debian includes waitpid there). \
    sed -i 's/util-linux-extra/util-linux/g' debian/control; \
    \
    # Write a clean debian/changelog with the correct version. \
    printf 'uwsm (%s-1) UNRELEASED; urgency=medium\n\n  * Upstream release %s.\n\n -- omakasui <omakasui@users.noreply.github.com>  %s\n' \
        "${VERSION}" "${VERSION}" "$(date -R)" > debian/changelog; \
    \
    dpkg-buildpackage -us -uc -b; \
    \
    mv /work/*.deb /output/
