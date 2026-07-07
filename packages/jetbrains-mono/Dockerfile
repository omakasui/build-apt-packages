# Downloads JetBrains Mono from the official JetBrains CDN and stages all TTFs.
# Upstream: https://github.com/JetBrains/JetBrainsMono

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    unzip \
  && rm -rf /var/lib/apt/lists/*

ARG VERSION

WORKDIR /work

RUN set -e; \
    curl -fsSL \
      "https://download.jetbrains.com/fonts/JetBrainsMono-${VERSION}.zip" \
      -o JetBrainsMono.zip; \
    unzip -q JetBrainsMono.zip -d JetBrainsMono; \
    \
    mkdir -p /output/staged/usr/share/fonts/truetype/jetbrains-mono; \
    find JetBrainsMono/fonts/ttf -maxdepth 1 -name "*.ttf" \
      -exec install -m 0644 {} /output/staged/usr/share/fonts/truetype/jetbrains-mono/ \;; \
    \
    echo "Staged $(ls /output/staged/usr/share/fonts/truetype/jetbrains-mono/*.ttf | wc -l) TTF files."