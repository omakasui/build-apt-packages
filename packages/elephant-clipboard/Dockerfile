# Builds elephant-clipboard provider plugin from source (Go).
# Upstream: https://github.com/abenz1267/elephant

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    golang \
    protobuf-compiler \
    gcc \
    libc6-dev \
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

# Build main binary first -- this warms the build cache for internal packages
# so the plugin below shares the same build IDs.
RUN go build \
    -ldflags="-s -w" \
    -buildvcs=false \
    -trimpath \
    -o /tmp/elephant \
    ./cmd/elephant

# Build clipboard provider plugin.
RUN CGO_ENABLED=1 go build \
    -ldflags="-s -w" \
    -buildvcs=false \
    -buildmode=plugin \
    -trimpath \
    -o /tmp/clipboard.so \
    ./internal/providers/clipboard

# Stage output.
RUN set -e; \
    mkdir -p /output/staged/usr/lib/elephant; \
    install -m 0755 /tmp/clipboard.so \
      /output/staged/usr/lib/elephant/clipboard.so; \
    echo "Staged: $(ls -lh /output/staged/usr/lib/elephant/clipboard.so)"