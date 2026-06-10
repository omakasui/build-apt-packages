# Upstream: https://github.com/anomalyco/opencode

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    fakeroot \
    dpkg-dev \
  && rm -rf /var/lib/apt/lists/*

ARG VERSION
ARG TARGETARCH

WORKDIR /build

RUN set -e; \
    case "${TARGETARCH}" in \
      amd64) OC_ARCH="x64"   ;; \
      arm64) OC_ARCH="arm64" ;; \
      *)     echo "Unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    \
    TARBALL="opencode-linux-${OC_ARCH}.tar.gz"; \
    URL="https://github.com/anomalyco/opencode/releases/download/v${VERSION}/${TARBALL}"; \
    \
    echo "Downloading ${URL}..."; \
    curl -fsSL "${URL}" -o "${TARBALL}"; \
    tar -xzf "${TARBALL}"

RUN set -e; \
    DEB_ROOT="/tmp/deb-opencode"; \
    mkdir -p "${DEB_ROOT}/DEBIAN"; \
    mkdir -p "${DEB_ROOT}/usr/bin"; \
    cp opencode "${DEB_ROOT}/usr/bin/opencode"; \
    chmod 755 "${DEB_ROOT}/usr/bin/opencode"; \
    SIZE=$(du -sk "${DEB_ROOT}" | cut -f1); \
    printf 'Package: opencode\n'                                    >  "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Version: %s\n'         "${VERSION}"                     >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Architecture: %s\n'    "${TARGETARCH}"                  >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Maintainer: omakasui <packages@omakasui.org>\n'         >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Installed-Size: %s\n'  "${SIZE}"                        >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Section: utils\n'                                       >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Priority: optional\n'                                   >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Homepage: https://github.com/anomalyco/opencode\n'      >> "${DEB_ROOT}/DEBIAN/control"; \
    printf 'Description: AI coding agent CLI\n'                     >> "${DEB_ROOT}/DEBIAN/control"; \
    printf ' OpenCode terminal interface installed to /usr/bin/opencode.\n' >> "${DEB_ROOT}/DEBIAN/control"; \
    mkdir -p /output; \
    fakeroot dpkg-deb --build "${DEB_ROOT}" \
      "/output/opencode_${VERSION}_${TARGETARCH}.deb"; \
    echo "Built: $(ls -lh /output/opencode_${VERSION}_${TARGETARCH}.deb)"
