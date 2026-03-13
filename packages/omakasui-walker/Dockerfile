# Metapackage — no files to install.
# The workflow assembles the .deb from the empty staged tree and the
# Depends field in package.yml pulls in walker, elephant, and all providers.

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

ARG VERSION

RUN mkdir -p /output/staged