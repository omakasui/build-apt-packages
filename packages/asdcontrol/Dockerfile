# Builds asdcontrol from source using g++.
# A simple C++ tool to control brightness of Apple Pro Display XDR / Studio Display on Linux.
# Fork: https://github.com/omakasui/asdcontrol

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /output && \
    curl -fsSL \
      "https://github.com/omakasui/asdcontrol/releases/download/v${VERSION}/asdcontrol_${VERSION}_${TARGETARCH}.deb" \
      -o "/output/asdcontrol_${VERSION}_${TARGETARCH}.deb"
