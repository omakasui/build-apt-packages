# Builds asdcontrol from source using g++.
# A simple C++ tool to control brightness of Apple Pro Display XDR / Studio Display on Linux.
# Fork: https://github.com/omakasui/asdcontrol

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

# Build dependencies.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    build-essential \
    g++ \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN curl -fsSL \
    "https://github.com/omakasui/asdcontrol/archive/refs/tags/v${VERSION}.tar.gz" \
    | tar -xz --strip-components=1 -C .

WORKDIR /build

RUN make

# Stage binary.
RUN install -Dm755 asdcontrol /output/staged/usr/local/bin/asdcontrol

# Stage udev rules for sudo-less HID device access.
RUN install -dm755 /output/staged/usr/lib/udev/rules.d && \
    printf 'KERNEL=="hiddev*", ATTRS{idVendor}=="05ac", ATTRS{idProduct}=="9243", GROUP="users", OWNER="root", MODE="0660"\n' \
      > /output/staged/usr/lib/udev/rules.d/60-asdcontrol.rules && \
    printf 'KERNEL=="hiddev*", ATTRS{idVendor}=="05ac", ATTRS{idProduct}=="1114", GROUP="users", OWNER="root", MODE="0660"\n' \
      >> /output/staged/usr/lib/udev/rules.d/60-asdcontrol.rules

# Stage maintainer scripts.
RUN mkdir -p /output/staged/DEBIAN
COPY postinst /output/staged/DEBIAN/postinst
COPY postrm   /output/staged/DEBIAN/postrm
RUN chmod 0755 /output/staged/DEBIAN/postinst \
               /output/staged/DEBIAN/postrm

RUN echo "Staged: $(du -sh /output/staged)"
