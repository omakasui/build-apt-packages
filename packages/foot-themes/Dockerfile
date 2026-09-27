# Color themes from the foot source tree, as in Debian's foot-themes.
# Upstream: https://codeberg.org/dnkl/foot

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN mkdir -p foot && \
    curl -fsSL \
      "https://codeberg.org/dnkl/foot/releases/download/${VERSION}/foot-${VERSION}.tar.gz" \
      -o foot.tar.gz && \
    tar -xzf foot.tar.gz --strip-components=1 -C foot

RUN install -d /output/staged/usr/share/foot/themes && \
    install -m644 foot/themes/* /output/staged/usr/share/foot/themes/ && \
    echo "Staged: $(ls /output/staged/usr/share/foot/themes | wc -l) themes"
