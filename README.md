# omakasui/build-apt-packages

Builds and publishes APT packages distributed via [omakasui/apt-packages](https://github.com/omakasui/apt-packages).

## versions.yml

```yaml
package-name:
  version: "1.2.3"
  depends_on: []        # sibling keys required at build time; workflow installs their .deb
  stable_release: false # true → publish to stable channel on push (default: dev only)
  auto_update: true     # false → exclude from automated version-update workflow
  frozen_suites: []     # suites to skip during builds
```

## package.yml

```yaml
name: package-example
type: build             # build (default) | repackage
arch: any               # any (default) | all (amd64-only)
section: utils
priority: optional
homepage: https://...
description: Short description.
produces: [package-example]  # installed names — used for filenames and Depends:
runtime_depends: []          # Depends: entries (package names, not keys)
distros: [debian13, ubuntu2404]
```

`type: build` — Dockerfile stages files under `/output/staged/`. The workflow assembles the `.deb`.
`type: repackage` — Dockerfile writes complete `.deb` files to `/output/`. The workflow tags filenames.
`ARG VERSION` must be declared in every Dockerfile. `BASE_IMAGE` and `TARGETARCH` are also available.
`conflicts`, `replaces`, `provides` are optional Debian control fields.

## Adding a package

1. Add an entry to `versions.yml` with the short upstream name.
2. Create `packages/<name>/Dockerfile` and `packages/<name>/package.yml`.
3. Push — the workflow detects the new entry and builds it automatically.

Manual trigger: GitHub > Actions > **Build package** > Run workflow.

## Inter-package dependencies

List sibling package keys in `depends_on`. The workflow downloads their `.deb` from the latest release and installs it in the build container before the build starts.

## Local build

Prerequisites: `docker` (with buildx), `yq`, `fakeroot`, `dpkg-deb`. For arm64: `qemu-user-static`. For `depends_on`: authenticated `gh`.

```bash
make help
make build PKG=fzf                   # default: debian13/amd64
make build PKG=ghostty DISTRO=ubuntu2404
make build PKG=starship ARCH=arm64
make lint PKG=fzf
make shell PKG=fzf
make list
make clean
```

Output: `output/<package>/`.
