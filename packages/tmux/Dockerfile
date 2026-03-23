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
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN curl -fsSL \
    "https://github.com/tmux/tmux/releases/download/${VERSION}/tmux-${VERSION}.tar.gz" \
    -o tmux.tar.gz && \
    tar -xzf tmux.tar.gz

WORKDIR /build/tmux-${VERSION}

RUN ./configure --prefix=/usr && \
    make -j"$(nproc)"

RUN install -Dm755 tmux /output/staged/usr/bin/tmux && \
    echo "Staged: $(ls -lh /output/staged/usr/bin/tmux)"