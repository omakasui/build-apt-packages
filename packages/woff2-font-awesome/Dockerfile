# Packages Font Awesome woff2 webfonts for use with walker and similar tools.
# Upstream: https://github.com/FortAwesome/Font-Awesome

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    unzip \
  && rm -rf /var/lib/apt/lists/*

ARG VERSION

RUN curl -fsSL \
    "https://github.com/FortAwesome/Font-Awesome/releases/download/${VERSION}/fontawesome-free-${VERSION}-web.zip" \
    -o /tmp/fa.zip && \
    unzip -q /tmp/fa.zip -d /tmp/fa && \
    rm /tmp/fa.zip

RUN set -e; \
    mkdir -p /output/staged/usr/share/fonts/woff2; \
    install -m 0644 /tmp/fa/fontawesome-free-${VERSION}-web/webfonts/*.woff2 \
      /output/staged/usr/share/fonts/woff2/; \
    echo "Staged: $(ls /output/staged/usr/share/fonts/woff2/)"