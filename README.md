# omakasui/build-apt-packages

Builds and publishes APT packages distributed via [omakasui/apt-packages](https://github.com/omakasui/apt-packages).

## Adding a package

1. Add an entry in `versions.yml` with the short upstream name (without the `omakasui-` prefix).
2. Create `packages/<name>/Dockerfile` and `packages/<name>/package.yml`.
3. Push - the workflow automatically detects the new entry.

## versions.yml

```yaml
package-name:
  version: "1.2.3"
  depends_on: []    # sibling packages required at build time
```

Only `version` is required.

`depends_on` is optional - it allows you to reference other packages in the repo without hardcoding versions. The workflow downloads the latest release's `.deb` files and installs them in the build container before building the new package.

`auto_update` - set to false to exclude from the update workflow. By default all packages are included.

`stable_release` - set to true to mark the package as stable and include it in the stable release workflow. By default all packages are built for dev releases.

`frozen_suites` - list of Debian/Ubuntu suites to exclude from the update workflow. By default all suites are included.

## package.yml

```yaml
name: omakasui-example
type: build           # build (default) | repackage
arch: any             # any (default) | all (amd64 only)
section: utils
priority: optional
homepage: https://...
description: >
  Short description.
produces:             # installed package names -> used for filename and Depends
  - omakasui-example
runtime_depends:
  - libfoo1
conflicts:            # optional
  - upstream-name
replaces:             # optional
  - upstream-name
provides:             # optional
  - upstream-name
distros:
  - debian13
  - ubuntu2404
```

## Package types

**`type: build`** - the Dockerfile compiles and writes files under `/output/staged/`. The workflow assembles the `.deb` from the `package.yml` metadata. Any maintainer scripts go in `/output/staged/DEBIAN/`.

**`type: repackage`** - the Dockerfile produces complete `.deb` packages directly in `/output/`. The workflow adds distro and arch tags to the filename.

In both cases the workflow passes `--build-arg VERSION=<version>` - declare `ARG VERSION` in every Dockerfile.

## Inter-package dependencies

`depends_on` accepts sibling keys. The workflow downloads already-built `.deb` files from the latest release and installs them in the container before building - no manual copying.

## Workflow

**Automatic build** - every push that modifies `versions.yml` or `packages/<name>/` triggers the build only for the affected packages.

**Manual build** - GitHub > Actions > **Build package** > Run workflow > enter the short package name (e.g. `gum`, not `omakasui-gum`).

## Local build

Prerequisites: `docker` (with buildx), `yq`, `fakeroot`, `dpkg-deb`. For arm64 cross-builds: `qemu-user-static`. For packages with `depends_on`: authenticated `gh` CLI.

```bash
make help                            # show all targets
make build PKG=fzf                   # build (default: debian13/amd64)
make build PKG=ghostty DISTRO=ubuntu2404
make build PKG=starship ARCH=arm64
make lint PKG=fzf                    # validate a package
make shell PKG=fzf                   # shell into the build container
make list                            # list packages with versions
make clean                           # remove output/
```

The `.deb` files are written to `output/<package>/`.
