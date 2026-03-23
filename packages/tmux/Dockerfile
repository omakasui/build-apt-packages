# Builds tmux from the upstream release tarball.
# Upstream: https://github.com/tmux/tmux
# Dependencies: libevent-dev, libncurses-dev (from distro packages).

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    build-essential \
    pkg-config \
    bison \
    libevent-dev \
    libncurses-dev \
  && rm -rf /var/lib/apt/lists/* \
  # Remove unversioned .so symlinks so the linker uses the static archive
  # instead of the shared library. This avoids soname mismatches between
  # Debian trixie (libevent_core-2.1.so.7t64) and Ubuntu noble (libevent_core-2.1.so.7).
  && find /usr/lib -name 'libevent*.so' ! -name '*.so.*' -delete

WORKDIR /build

RUN curl -fsSL \
    "https://github.com/tmux/tmux/releases/download/${VERSION}/tmux-${VERSION}.tar.gz" \
    -o tmux.tar.gz && \
    tar -xzf tmux.tar.gz

WORKDIR /build/tmux-${VERSION}

# libevent .so symlinks were removed above, so the autoconf check and
# pkg-config will resolve to the static archive automatically.
RUN ./configure --prefix=/usr && \
    make -j"$(nproc)"

RUN install -Dm755 tmux /output/staged/usr/bin/tmux && \
    echo "Staged: $(ls -lh /output/staged/usr/bin/tmux)" && \
    ldd /output/staged/usr/bin/tmux