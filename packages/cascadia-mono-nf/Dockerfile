# Downloads CascadiaMono Nerd Font from ryanoasis/nerd-fonts and stages all TTFs.
# Upstream: https://github.com/ryanoasis/nerd-fonts

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
      "https://github.com/ryanoasis/nerd-fonts/releases/download/v${VERSION}/CascadiaMono.zip" \
      -o CascadiaMono.zip; \
    unzip -q CascadiaMono.zip -d CascadiaMono; \
    \
    mkdir -p /output/staged/usr/share/fonts/truetype/cascadia-mono-nf; \
    find CascadiaMono -maxdepth 1 -name "*.ttf" \
      -exec install -m 0644 {} /output/staged/usr/share/fonts/truetype/cascadia-mono-nf/ \;; \
    \
    echo "Staged $(ls /output/staged/usr/share/fonts/truetype/cascadia-mono-nf/*.ttf | wc -l) TTF files."

# Stage postinst.
RUN mkdir -p /output/staged/DEBIAN
COPY postinst /output/staged/DEBIAN/postinst
RUN chmod 0755 /output/staged/DEBIAN/postinst