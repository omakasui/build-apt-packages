# Downloads iA Writer Mono Static TTFs from the iA-Fonts repository.
# Upstream: https://github.com/iaolo/iA-Fonts

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
      "https://github.com/iaolo/iA-Fonts/archive/refs/heads/master.zip" \
      -o iafonts.zip; \
    unzip -q iafonts.zip -d iaFonts; \
    \
    mkdir -p /output/staged/usr/share/fonts/truetype/ia-writer-mono; \
    find "iaFonts/iA-Fonts-master/iA Writer Mono/Static" -maxdepth 1 -name "iAWriterMonoS-*.ttf" \
      -exec install -m 0644 {} /output/staged/usr/share/fonts/truetype/ia-writer-mono/ \;; \
    \
    echo "Staged $(ls /output/staged/usr/share/fonts/truetype/ia-writer-mono/*.ttf | wc -l) TTF files."

# Stage postinst.
RUN mkdir -p /output/staged/DEBIAN
COPY postinst /output/staged/DEBIAN/postinst
RUN chmod 0755 /output/staged/DEBIAN/postinst