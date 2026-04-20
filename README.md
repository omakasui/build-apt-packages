# omakasui/build-apt-packages

Builds and publishes APT packages distributed via [omakasui/apt-packages](https://github.com/omakasui/apt-packages).

## Repository layout

```
versions.yml          — source of truth for versions
build-matrix.yml      — supported distros and architectures
Makefile              — developer commands (make help)
packages/<name>/
  Dockerfile          — build environment (receives ARG VERSION)
  package.yml         — package metadata
scripts/
  lib/common.sh       — shared shell functions (logging, paths, require_cmd)
  lib/metadata.sh     — YAML metadata helpers (versions, deps, matrix)
  build-local.sh      — local package build driver
  detect-changes.sh   — detect changed packages and emit CI matrices
  download-deps.sh    — download dependency .debs from GitHub Releases
  extract-and-assemble.sh — extract Docker output → .deb (used by CI and local)
  assemble-deb.sh     — staged tree → .deb assembly
  repackage-deb.sh    — upstream .deb repackaging
  resolve-dep-name.sh — dependency name resolution
  lint-package.sh     — package definition validator
  install-yq.sh       — CI yq installer (idempotent)
```

## Naming convention

Keys in `versions.yml` use **short upstream names** (e.g. `gum`, `lazygit`).
The installed package name may differ, always check `produces[]` in `package.yml`.

Packages compiled or repackaged under the omakasui namespace are installed as
`omakasui-<name>` and may include `Conflicts/Replaces/Provides` for the upstream name,
making them drop-in replacements. Some packages (`omakasui-aether`, `omakasui-nvim`,
`omakasui-walker`, `omakasui-zellij`) also produce `omakub-<name>` and `omadeb-<name>`
variants from the same build via `produces[]` in `package.yml`. The folder under
`packages/` and the GitHub release tag always use the short key (e.g. `packages/gum/`,
tag `gum-0.17.0`).

## Package types

### `type: build` (default)

The Dockerfile compiles or installs files and places them under `/output/staged/`.
The workflow assembles the final `.deb` using metadata from `package.yml`.

Optional: stage `DEBIAN/postinst` (or other maintainer scripts) under `/output/staged/DEBIAN/`,
so the workflow includes them in the final package automatically.

Required `package.yml` fields: `section`, `priority`, `homepage`, `description`, `distros`.

### `type: repackage`

The Dockerfile produces complete `.deb` files directly in `/output/`.
The workflow injects the distro and arch tags into the filename.

Required `package.yml` fields: `produces`, `distros`.

In both cases the workflow passes `--build-arg VERSION=<version>` — declare `ARG VERSION` in every Dockerfile.

## Dockerfile contract

| Type | Dockerfile must write to |
|------|--------------------------|
| `build` | `/output/staged/` (staged file tree; `DEBIAN/` allowed for maintainer scripts) |
| `repackage` | `/output/<name>_<version>_<arch>.deb` (complete debs) |

`BASE_IMAGE` and `TARGETARCH` are also passed as build-args if needed.

## versions.yml

```yaml
# Keys are short upstream names — do NOT use the omakasui- prefix here.
# The installed package name is determined by produces[] in package.yml.
package-name:
  version: "1.2.3"
  depends_on: []    # sibling packages required at build time (installed before docker build)
```

Pushing a change here triggers a build for the affected packages only.
Multi-package commits are supported.

## package.yml fields

```yaml
name: omakasui-example
type: build           # build (default) | repackage
arch: any             # any (default) | all (architecture-independent, builds amd64 only)
section: utils
priority: optional
homepage: https://...
description: >
  Short one-line description.
  Additional lines become the long description.
produces:             # installed package names — used for filenames and Depends: fields
  - omakasui-example  # list multiple names to emit one .deb per name (e.g. omakub-*, omadeb-*)
runtime_depends:      # runtime Depends: entries (package names, not keys)
  - libfoo1
conflicts:            # Conflicts: entries — optional
  - upstream-name
replaces:             # Replaces: entries — optional
  - upstream-name
provides:             # Provides: entries — optional
  - upstream-name
distros:
  - debian13
  - ubuntu2404
```

## Adding a package

1. Add an entry to `versions.yml` using the short upstream name.
2. Create `packages/<name>/Dockerfile` and `packages/<name>/package.yml`.
3. Set `produces: [omakasui-<name>]` if the installed name should differ from the key.
4. Push — the workflow detects the new entry automatically.

## Custom dependencies

List sibling package keys in `depends_on`. The workflow downloads their built `.deb`
from the latest release and installs them inside the Docker build container before
the build starts — no manual copying required.

## Manual rebuild

GitHub > Actions > **Build package** > Run workflow > enter the short package name
(e.g. `gum`, not `omakasui-gum`). Version is always read from `versions.yml`.

## Local build

Build and test a package on your machine without pushing to CI.

### Prerequisites

`docker` (with buildx), `yq` ([mikefarah/yq](https://github.com/mikefarah/yq)), `fakeroot`, `dpkg-deb`.
For arm64 cross-builds: `qemu-user-static`.
For packages with `depends_on`: `gh` CLI (authenticated).

### Makefile targets

```bash
make help                          # show all targets
make build PKG=fzf                 # build (default: debian13/amd64)
make build PKG=ghostty DISTRO=ubuntu2404
make build PKG=starship ARCH=arm64
make lint                          # validate all packages
make lint PKG=fzf                  # validate one package
make list                          # list packages with versions
make info PKG=fzf                  # show package metadata
make shell PKG=fzf                 # open shell in build container
make clean                         # remove output/
make clean-images                  # remove build Docker images
```

Output `.deb` files are written to `output/<package>/`.