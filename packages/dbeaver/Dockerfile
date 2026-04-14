# Repackages the upstream DBeaver Community Edition .deb.
# Downloads the prebuilt .deb from GitHub Releases for the target arch.
# Upstream: https://github.com/dbeaver/dbeaver
#
# Asset naming convention:
#   amd64 → dbeaver-ce-<VERSION>-linux-x86_64.deb
#   arm64 → dbeaver-ce-<VERSION>-linux-aarch64.deb

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    dpkg-dev \
    wget \
  && rm -rf /var/lib/apt/lists/* \
  && wget -qO /usr/local/bin/yq \
       https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
  && chmod +x /usr/local/bin/yq

WORKDIR /build

COPY package.yml package.yml

RUN set -e; \
    case "${TARGETARCH}" in \
      amd64)  UPSTREAM_ARCH="x86_64"  ;; \
      arm64)  UPSTREAM_ARCH="aarch64" ;; \
      *)      echo "ERROR: unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac; \
    DEB_FILE="dbeaver-ce-${VERSION}-linux-${UPSTREAM_ARCH}.deb"; \
    curl -fsSL \
      "https://github.com/dbeaver/dbeaver/releases/download/${VERSION}/${DEB_FILE}" \
      -o upstream.deb; \
    \
    mkdir -p extracted; \
    dpkg-deb -R upstream.deb extracted; \
    \
    # Keep only the first stanza. \
    awk 'BEGIN{p=1} /^$/{p=0} p{print}' extracted/DEBIAN/control \
      > /tmp/control.clean && mv /tmp/control.clean extracted/DEBIAN/control; \
    \
    # Inject Conflicts/Replaces/Provides from package.yml. \
    CONFLICTS=$(yq e '.conflicts // [] | join(", ")' package.yml); \
    REPLACES=$(yq e '.replaces  // [] | join(", ")' package.yml); \
    PROVIDES=$(yq e '.provides  // [] | join(", ")' package.yml); \
    [[ -n "$CONFLICTS" ]] && { grep -q "^Conflicts:" extracted/DEBIAN/control \
      || echo "Conflicts: $CONFLICTS" >> extracted/DEBIAN/control; }; \
    [[ -n "$REPLACES"  ]] && { grep -q "^Replaces:"  extracted/DEBIAN/control \
      || echo "Replaces: $REPLACES"   >> extracted/DEBIAN/control; }; \
    [[ -n "$PROVIDES"  ]] && { grep -q "^Provides:"  extracted/DEBIAN/control \
      || echo "Provides: $PROVIDES"   >> extracted/DEBIAN/control; }; \
    \
    # Remove empty conffiles lines if present. \
    if [[ -f extracted/DEBIAN/conffiles ]]; then \
      sed -i '/^[[:space:]]*$/d' extracted/DEBIAN/conffiles; \
      [[ ! -s extracted/DEBIAN/conffiles ]] && rm extracted/DEBIAN/conffiles; \
    fi; \
    \
    mkdir -p /output; \
    dpkg-deb -b extracted "/output/dbeaver-ce_${VERSION}_${TARGETARCH}.deb"; \
    echo "Built: $(ls -lh /output/dbeaver-ce_${VERSION}_${TARGETARCH}.deb)"