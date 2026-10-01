# Builds omakasui-archive-keyring (packages.omakasui.org key) from the
# omakasui/keyrings repo. omakasui-core-archive-keyring comes from the same
# source but is published by omakasui/build-apt-omakasui.

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    dpkg-dev \
    debhelper \
    fakeroot \
    gpg \
    git \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

ARG VERSION
ARG SUITE

WORKDIR /build

RUN git clone --depth=1 --branch "v${VERSION}" \
      https://github.com/omakasui/keyrings.git keyrings

WORKDIR /build/keyrings

RUN dpkg-buildpackage -b -uc -us

RUN mkdir -p /output && \
    cp /build/omakasui-archive-keyring_*.deb \
       "/output/omakasui-archive-keyring_${VERSION}-1+${SUITE}_all.deb"
