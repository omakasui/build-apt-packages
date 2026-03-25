# Builds omakasui/aether — a Go/Wails desktop theming app.
# Compiles the GUI binary (wails build) and the aether-wp CLI tool.
# Stages binaries, .desktop file, and icon into /output/staged/.
# Upstream: https://github.com/omakasui/aether

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    build-essential \
    pkg-config \
    libgtk-3-dev \
    libwebkit2gtk-4.1-dev \
    libgtk-layer-shell-dev \
    libgstreamer1.0-dev \
  && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 from NodeSource (distro npm is too old for @tailwindcss/oxide optional deps)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

# Install Go 1.23
RUN curl -fsSL "https://go.dev/dl/go1.23.8.linux-$(dpkg --print-architecture).tar.gz" \
    | tar -C /usr/local -xzf -
ENV PATH="/usr/local/go/bin:/root/go/bin:${PATH}"

# Install Wails CLI
RUN go install github.com/wailsapp/wails/v2/cmd/wails@v2.11.0

ARG VERSION

WORKDIR /build

# Copy local assets from the build context.
COPY aether.png aether.png
COPY aether.desktop aether.desktop

RUN set -e; \
    URL="https://github.com/omakasui/aether/archive/v${VERSION}.tar.gz"; \
    echo "Downloading ${URL}..."; \
    curl -fsSL "${URL}" -o aether.tar.gz; \
    tar -xzf aether.tar.gz; \
    mv "aether-${VERSION}" aether

WORKDIR /build/aether

# Build aether-wp CLI tool
RUN go build -o build/bin/aether-wp ./cmd/aether-wp/

# Build the Wails GUI binary
RUN wails build -tags webkit2_41 -ldflags "-X aether/cli.Version=${VERSION}"

# Stage files for packaging
RUN set -e; \
    install -Dm755 build/bin/aether    /output/staged/usr/bin/aether; \
    install -Dm755 build/bin/aether-wp /output/staged/usr/bin/aether-wp; \
    \
    install -Dm644 /build/aether.desktop \
      /output/staged/usr/share/applications/aether.desktop; \
    \
    install -Dm644 /build/aether.png \
      /output/staged/usr/share/icons/hicolor/512x512/apps/aether.png; \
    \
    echo "Staged: $(du -sh /output/staged)"