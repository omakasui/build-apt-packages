# omakasui/build-apt-packages

Builds and publishes APT packages distributed via [omakasui/apt-packages](https://github.com/omakasui/apt-packages).

## versions.yml

One entry per package, keyed by its short upstream name:

```yaml
package-name:
  version: "1.2.3"
  depends_on: []
  stable_release: false
  auto_update: true
  frozen_suites: []
```

| Field | Default | Description |
| --- | --- | --- |
| `version` | required | Upstream version to build. |
| `depends_on` | `[]` | Sibling keys required at build time. The workflow installs their `.deb`. |
| `stable_release` | `false` | Set to `true` to publish to the stable channel on push. Otherwise dev only. |
| `auto_update` | `true` | Set to `false` to exclude the package from the automated version-update workflow. |
| `frozen_suites` | `[]` | Suites to skip during builds. |

## package.yml

```yaml
name: package-example
type: build
arch: any
section: utils
priority: optional
homepage: https://...
description: Short description.
produces: [package-example]
runtime_depends: []
distros: [debian13, ubuntu2404]
```

| Field | Default | Description |
| --- | --- | --- |
| `type` | `build` | Either `build` or `repackage`. See below. |
| `arch` | `any` | Use `all` for amd64-only packages. |
| `produces` | required | Installed names, used for filenames and `Depends:`. |
| `runtime_depends` | `[]` | `Depends:` entries, given as package names rather than keys. |
| `distros` | required | Target distributions. |

Optional Debian control fields: `conflicts`, `replaces`, `provides`.

### Build types

* **`type: build`**: the Dockerfile stages files under `/output/staged/` and the workflow assembles the `.deb`.
* **`type: repackage`**: the Dockerfile writes complete `.deb` files to `/output/` and the workflow tags the filenames.

### Dockerfile arguments

* `ARG VERSION` must be declared in every Dockerfile.
* `BASE_IMAGE` and `TARGETARCH` are also available.

## Adding a package

1. Add an entry to `versions.yml` with the short upstream name.
2. Create `packages/<name>/Dockerfile` and `packages/<name>/package.yml`.
3. Push. The workflow detects the new entry and builds it automatically.

Manual trigger: GitHub > Actions > **Build package** > Run workflow.

## Inter-package dependencies

List sibling package keys in `depends_on`. The workflow downloads their `.deb` from the latest release and installs it in the build container before the build starts.

## Local build

Prerequisites:

* `docker` (with buildx)
* `yq`
* `fakeroot`
* `dpkg-deb`
* `qemu-user-static` (arm64 builds only)
* authenticated `gh` (packages using `depends_on` only)

```bash
make help
make build PKG=fzf                        # default: debian13/amd64
make build PKG=ghostty DISTRO=ubuntu2404
make build PKG=starship ARCH=arm64
make lint PKG=fzf
make shell PKG=fzf
make list
make clean
```

Output: `output/<package>/`.
