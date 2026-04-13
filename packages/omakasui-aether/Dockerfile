# Packages the aether configuration for omakasui/omakub/omadeb variants.
# Upstream: https://github.com/bjarneo/aether

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    fakeroot \
  && rm -rf /var/lib/apt/lists/*

ARG VERSION
ARG TARGETARCH

WORKDIR /build

COPY setup-aether.template setup-aether.template

# ── Package three .deb variants ──────────────────────────────────────────
RUN set -e; \
    mkdir -p /output; \
    for PROJECT in omakasui omakub omadeb; do \
      PKG_NAME="${PROJECT}-aether"; \
      STAGED="/tmp/staged-${PROJECT}"; \
      \
      # Project-specific setup script \
      SETUP="${STAGED}/usr/bin/${PROJECT}-setup-aether"; \
      mkdir -p "${STAGED}/usr/bin"; \
      sed \
        -e "s|{{PROJECT}}|${PROJECT}|g" \
        -e "s|{{PKG_NAME}}|${PKG_NAME}|g" \
        setup-aether.template > "$SETUP"; \
      chmod 755 "$SETUP"; \
      \
      # Build .deb \
      DEB_ROOT="/tmp/deb-${PROJECT}"; \
      mkdir -p "${DEB_ROOT}/DEBIAN"; \
      cp -r "${STAGED}/." "${DEB_ROOT}/"; \
      SIZE=$(du -sk "$STAGED" | cut -f1); \
      printf "Package: %s\nVersion: %s\nArchitecture: all\n" \
        "${PKG_NAME}" "${VERSION}" > "${DEB_ROOT}/DEBIAN/control"; \
      printf "Maintainer: omakasui <packages@omakasui.org>\n" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf "Installed-Size: %s\n" "${SIZE}" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf "Depends: aether, gum\n" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf "Section: gnome\nPriority: optional\n" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf "Homepage: https://github.com/bjarneo/aether\n" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf "Description: Aether theme integration for %s\n" "${PROJECT}" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf " Setup script that links Aether themes into the %s theme list.\n" "${PROJECT}" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      \
      fakeroot dpkg-deb --build "${DEB_ROOT}" \
        "/output/${PKG_NAME}_${VERSION}_all.deb"; \
      echo "Built: $(ls -lh /output/${PKG_NAME}_${VERSION}_all.deb)"; \
    done
