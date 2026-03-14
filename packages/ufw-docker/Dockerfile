# Packages the ufw-docker shell script from upstream.
# Upstream: https://github.com/chaifeng/ufw-docker
# The script is downloaded directly from the tagged commit — no build required.

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

ARG VERSION

RUN curl -fsSL \
    "https://github.com/chaifeng/ufw-docker/raw/refs/tags/${VERSION}/ufw-docker" \
    -o /tmp/ufw-docker && \
    chmod +x /tmp/ufw-docker

RUN set -e; \
    mkdir -p /output/staged/usr/local/bin; \
    install -m 0755 /tmp/ufw-docker /output/staged/usr/local/bin/ufw-docker; \
    echo "Staged: $(ls -lh /output/staged/usr/local/bin/ufw-docker)"