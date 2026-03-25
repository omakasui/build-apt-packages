# Packages aether integration for omakasui/omakub/omadeb variants.
# Produces three .deb files in /output/:
#   omakasui-aether_<version>_all.deb
#   omakub-aether_<version>_all.deb
#   omadeb-aether_<version>_all.deb
# Each .deb installs:
#   /usr/bin/<project>-aether-setup (generated from aether-setup.template)
# Upstream: https://github.com/bjarneo/aether

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

ARG VERSION

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    fakeroot \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY aether-setup.template aether-setup.template

RUN set -e; \
    mkdir -p /output; \
    for PROJECT in omakasui omakub omadeb; do \
      PKG_NAME="${PROJECT}-aether"; \
      STAGED="/tmp/staged-${PROJECT}"; \
      \
      # Instantiate setup script from template. \
      mkdir -p "${STAGED}/usr/bin"; \
      SETUP="${STAGED}/usr/bin/${PKG_NAME}-setup"; \
      sed \
        -e "s|{{PROJECT}}|${PROJECT}|g" \
        -e "s|{{PKG_NAME}}|${PKG_NAME}|g" \
        /build/aether-setup.template > "$SETUP"; \
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
      printf "Depends: aether, gum\n" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf "Section: gnome\nPriority: optional\n" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf "Homepage: https://github.com/bjarneo/aether\n" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf "Description: Aether theme integration for %s\n" "${PROJECT}" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf " Creates the symlink between Aether and the %s theme system\n" "${PROJECT}" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf " so Aether-generated themes appear in the project theme list.\n" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      printf " Run %s-setup to activate for the current user.\n" "${PKG_NAME}" \
        >> "${DEB_ROOT}/DEBIAN/control"; \
      \
      fakeroot dpkg-deb --build "${DEB_ROOT}" \
        "/output/${PKG_NAME}_${VERSION}_all.deb"; \
      echo "Built: $(ls -lh /output/${PKG_NAME}_${VERSION}_all.deb)"; \
    done
