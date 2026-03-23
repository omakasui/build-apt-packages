# Repackages the upstream official glab .deb under the omakasui namespace.
# Downloads the prebuilt .deb from GitLab releases for the target arch.
# Upstream: https://gitlab.com/gitlab-org/cli

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    dpkg-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN set -e; \
    DEB_FILE="glab_${VERSION}_linux_${TARGETARCH}.deb"; \
    curl -fsSL \
      "https://gitlab.com/gitlab-org/cli/-/releases/v${VERSION}/downloads/${DEB_FILE}" \
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
    # Remove empty conffiles lines if present. \
    if [[ -f extracted/DEBIAN/conffiles ]]; then \
      sed -i '/^[[:space:]]*$/d' extracted/DEBIAN/conffiles; \
      [[ ! -s extracted/DEBIAN/conffiles ]] && rm extracted/DEBIAN/conffiles; \
    fi; \
    \
    mkdir -p /output; \
    dpkg-deb -b extracted "/output/glab_${VERSION}_${TARGETARCH}.deb"; \
    echo "Built: $(ls -lh /output/glab_${VERSION}_${TARGETARCH}.deb)"