# Builds elephant from source (Go).
# Includes the desktopapplications provider plugin.
# Upstream: https://github.com/abenz1267/elephant

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    golang \
    protobuf-compiler \
  && rm -rf /var/lib/apt/lists/*

# Install protoc-gen-go.
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@latest && \
    go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

ARG VERSION

WORKDIR /build

RUN curl -fsSL \
    "https://github.com/abenz1267/elephant/archive/refs/tags/v${VERSION}.tar.gz" \
    -o src.tar.gz && \
    tar -xzf src.tar.gz && \
    mv "elephant-${VERSION}" elephant

WORKDIR /build/elephant

# Generate protobuf bindings.
RUN PATH="$PATH:$(go env GOPATH)/bin" go generate ./... 2>/dev/null || true

# Build main binary.
RUN go build -o /tmp/elephant ./cmd/elephant

# Build desktopapplications provider plugin (requires CGO for plugin mode).
RUN CGO_ENABLED=1 go build -buildmode=plugin \
    -o /tmp/desktopapplications.so \
    ./internal/providers/desktopapplications

# Stage output.
RUN set -e; \
    mkdir -p /output/staged/usr/bin; \
    install -m 0755 /tmp/elephant /output/staged/usr/bin/elephant; \
    \
    # Providers go to /usr/lib/elephant/ — elephant looks here at startup. \
    mkdir -p /output/staged/usr/lib/elephant; \
    install -m 0755 /tmp/desktopapplications.so \
      /output/staged/usr/lib/elephant/desktopapplications.so; \
    \
    echo "Staged: $(du -sh /output/staged)"