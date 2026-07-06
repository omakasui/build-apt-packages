# Upstream: https://github.com/obsidianmd/obsidian-releases

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN set -e; \
    case "${TARGETARCH}" in \
      amd64)  TARBALL="obsidian-${VERSION}.tar.gz"       ;; \
      arm64)  TARBALL="obsidian-${VERSION}-arm64.tar.gz" ;; \
      *)      echo "ERROR: unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL \
      "https://github.com/obsidianmd/obsidian-releases/releases/download/v${VERSION}/${TARBALL}" \
      -o obsidian.tar.gz; \
    mkdir -p obsidian; \
    tar -xzf obsidian.tar.gz -C obsidian --strip-components=1

RUN set -e; \
    mkdir -p staged/opt/obsidian; \
    cp -r obsidian/. staged/opt/obsidian/; \
    chmod 755 staged/opt/obsidian/obsidian; \
    \
    mkdir -p staged/usr/bin; \
    ln -sf /opt/obsidian/obsidian staged/usr/bin/obsidian; \
    \
    mkdir -p staged/usr/share/applications; \
    printf '%s\n' \
      '[Desktop Entry]' \
      'Name=Obsidian' \
      'Comment=A powerful knowledge base that works on top of local Markdown files' \
      'Keywords=notes;markdown;knowledge;pkm;wiki' \
      'Exec=/opt/obsidian/obsidian %u' \
      'Icon=/opt/obsidian/obsidian.png' \
      'Terminal=false' \
      'StartupNotify=true' \
      'StartupWMClass=obsidian' \
      'NoDisplay=false' \
      'Type=Application' \
      'MimeType=x-scheme-handler/obsidian;' \
      'Categories=Office;' \
      > staged/usr/share/applications/obsidian.desktop

# Copy staged tree to output for external assembly by build.sh.
RUN mkdir -p /output/staged && cp -r staged/. /output/staged/

RUN echo "Staged: $(find /output/staged -type f | wc -l) files"
