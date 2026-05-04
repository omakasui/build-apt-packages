# Upstream: https://github.com/cli/cli

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
    DEB_FILE="gh_${VERSION}_linux_${TARGETARCH}.deb"; \
    curl -fsSL \
      "https://github.com/cli/cli/releases/download/v${VERSION}/${DEB_FILE}" \
      -o upstream.deb; \
    \
    # Extract, clean control file, rebuild. \
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
    [[ -n "$CONFLICTS" ]] && grep -q "^Conflicts:" extracted/DEBIAN/control \
      || { [[ -n "$CONFLICTS" ]] && echo "Conflicts: $CONFLICTS" >> extracted/DEBIAN/control; }; \
    [[ -n "$REPLACES"  ]] && grep -q "^Replaces:"  extracted/DEBIAN/control \
      || { [[ -n "$REPLACES"  ]] && echo "Replaces: $REPLACES"   >> extracted/DEBIAN/control; }; \
    [[ -n "$PROVIDES"  ]] && grep -q "^Provides:"  extracted/DEBIAN/control \
      || { [[ -n "$PROVIDES"  ]] && echo "Provides: $PROVIDES"   >> extracted/DEBIAN/control; }; \
    \
    # Remove empty conffiles lines if present. \
    if [[ -f extracted/DEBIAN/conffiles ]]; then \
      sed -i '/^[[:space:]]*$/d' extracted/DEBIAN/conffiles; \
      [[ ! -s extracted/DEBIAN/conffiles ]] && rm extracted/DEBIAN/conffiles; \
    fi; \
    \
    mkdir -p /output; \
    dpkg-deb -b extracted "/output/gh_${VERSION}_${TARGETARCH}.deb"; \
    echo "Built: $(ls -lh /output/gh_${VERSION}_${TARGETARCH}.deb)"
