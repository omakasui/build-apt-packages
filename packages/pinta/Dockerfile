# Builds Pinta from the upstream release tarball and bundles the .NET 8
# runtime alongside it, so no external dotnet package is needed at install time.
# This avoids the dotnet-runtime-8 availability issue on Debian trixie.
# Upstream: https://github.com/PintaProject/Pinta
# Requires: GTK >= 4.12, libadwaita >= 1.4 (satisfied by trixie and noble).

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    build-essential \
    autoconf \
    autotools-dev \
    autoconf-archive \
    gettext \
    intltool \
    libadwaita-1-dev \
    webp-pixbuf-loader \
  && rm -rf /var/lib/apt/lists/*

# Install .NET 8 SDK via official tarball (distro-agnostic).
ENV DOTNET_ROOT=/opt/dotnet-sdk
ENV PATH="${DOTNET_ROOT}:${PATH}"

RUN set -e; \
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh; \
    chmod +x /tmp/dotnet-install.sh; \
    /tmp/dotnet-install.sh \
      --channel 8.0 \
      --install-dir "${DOTNET_ROOT}" \
      --no-path; \
    rm /tmp/dotnet-install.sh; \
    dotnet --version

WORKDIR /build

RUN curl -fsSL \
    "https://github.com/PintaProject/Pinta/releases/download/${VERSION}/pinta-${VERSION}.tar.gz" \
    -o pinta.tar.gz && \
    tar -xzf pinta.tar.gz

WORKDIR /build/pinta-${VERSION}

RUN ./configure --prefix=/usr

RUN make -j"$(nproc)"

# Install Pinta files to staged tree.
RUN make install DESTDIR=/output/staged

# Bundle the .NET 8 runtime (not the full SDK) alongside Pinta.
# Installed to /opt/dotnet-pinta/ — isolated, does not conflict with
# any system dotnet installation.
RUN set -e; \
    RUNTIME_DIR="/output/staged/opt/dotnet-pinta"; \
    mkdir -p "${RUNTIME_DIR}"; \
    /tmp/../opt/dotnet-sdk/dotnet-install.sh 2>/dev/null || true; \
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh; \
    chmod +x /tmp/dotnet-install.sh; \
    /tmp/dotnet-install.sh \
      --channel 8.0 \
      --runtime dotnet \
      --install-dir "${RUNTIME_DIR}" \
      --no-path; \
    rm /tmp/dotnet-install.sh; \
    echo "Bundled runtime: $(ls ${RUNTIME_DIR}/shared/Microsoft.NETCore.App/)"

# Wrap the Pinta launcher to point at the bundled runtime.
RUN set -e; \
    PINTA_BIN="/output/staged/usr/bin/pinta"; \
    PINTA_ORIG="/output/staged/usr/bin/pinta.real"; \
    if [[ -f "${PINTA_BIN}" ]]; then \
      mv "${PINTA_BIN}" "${PINTA_ORIG}"; \
      printf '#!/bin/bash\nexport DOTNET_ROOT=/opt/dotnet-pinta\nexec "%s" "$@"\n' \
        "${PINTA_ORIG#/output/staged}" > "${PINTA_BIN}"; \
      chmod 755 "${PINTA_BIN}"; \
    fi; \
    echo "Staged: $(find /output/staged -type f | wc -l) files"