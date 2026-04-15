# Packages the zellij configuration for omakasui/omakub/omadeb variants.
# Upstream: https://github.com/zellij-org/zellij

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

ARG VERSION

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    fakeroot \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY config.kdl            config.kdl
COPY setup-zellij.template setup-zellij.template

RUN set -e; \
    mkdir -p /output; \
    for PROJECT in omakasui omakub omadeb omari; do \
      PKG_NAME="${PROJECT}-zellij"; \
      SHARE_DIR="/usr/share/${PKG_NAME}"; \
      STAGED="/tmp/staged-${PROJECT}"; \
      \
      # Stage config. \
      mkdir -p "${STAGED}${SHARE_DIR}/config"; \
      cp config.kdl "${STAGED}${SHARE_DIR}/config/config.kdl"; \
      chmod -R 755 "${STAGED}${SHARE_DIR}"; \
      find "${STAGED}${SHARE_DIR}" -type f -exec chmod 644 {} \;; \
      \
      # Instantiate setup script from template. \
      mkdir -p "${STAGED}/usr/bin"; \
      SETUP="${STAGED}/usr/bin/${PROJECT}-setup-zellij"; \
      sed \
        -e "s|{{PROJECT}}|${PROJECT}|g" \
        -e "s|{{PKG_NAME}}|${PKG_NAME}|g" \
        /build/setup-zellij.template > "$SETUP"; \
      chmod 755 "$SETUP"; \
      \
      # Write DEBIAN/control. \
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
      printf "Depends: zellij, gum\n" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf "Section: utils\nPriority: optional\n" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf "Homepage: https://zellij.dev\n" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf "Description: Zellij configuration for %s\n" "${PROJECT}" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf " Installs omakub-based zellij config and a setup script.\n" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf " Run %s-setup-zellij to activate for the current user.\n" "${PROJECT}" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      \
      fakeroot dpkg-deb --build "${DEB_ROOT}" \
        "/output/${PKG_NAME}_${VERSION}_all.deb"; \
      echo "Built: $(ls -lh /output/${PKG_NAME}_${VERSION}_all.deb)"; \
    done