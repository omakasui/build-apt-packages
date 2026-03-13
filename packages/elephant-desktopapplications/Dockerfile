# Builds elephant desktopapplications provider plugin from source (Go).
# Must be compiled with the same Go version as elephant.
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

# Build desktopapplications provider plugin (requires CGO for plugin mode).
RUN CGO_ENABLED=1 go build -buildmode=plugin \
    -o /tmp/desktopapplications.so \
    ./internal/providers/desktopapplications

# Stage output.
# Elephant looks for provider plugins in /usr/lib/elephant/.
RUN set -e; \
    mkdir -p /output/staged/usr/lib/elephant; \
    install -m 0755 /tmp/desktopapplications.so \
      /output/staged/usr/lib/elephant/desktopapplications.so; \
    echo "Staged: $(ls -lh /output/staged/usr/lib/elephant/desktopapplications.so)"