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

Build metadata only. All Debian control fields live in `debian/control`, not here.

```yaml
type: build
distros: [debian13, ubuntu2404]
```

| Field | Default | Description |
| --- | --- | --- |
| `type` | `build` | One of `build`, `repackage`, `passthrough`. See below. |
| `distros` | required | Target distributions. Keys must exist in `build-matrix.yml`. |
| `arch` | unset | Restrict the build. `amd64` builds amd64 only; `all` also marks the package `Architecture: all` (use it for arch-independent content, not for compiled binaries). |
| `produces` | key name | Installed names, used for `.deb` filenames. Only needed when they differ from the `versions.yml` key. |
| `source` | — | `passthrough` only: `url` or `url_<arch>` of the upstream `.deb`. |

### Build types

* **`type: build`**: the Dockerfile stages files under `/output/staged/` and `scripts/build.sh` assembles the `.deb` from `debian/`.
* **`type: repackage`**: the Dockerfile writes complete `.deb` files to `/output/` and the workflow tags the filenames.
* **`type: passthrough`**: no Dockerfile. The upstream `.deb` is downloaded and `debian/control` is applied as an overlay.

### Dockerfile arguments

* `ARG VERSION` must be declared in every Dockerfile.
* `BASE_IMAGE` and `TARGETARCH` are also available.

## debian/

Required for `build` and `passthrough` packages. `scripts/build.sh` substitutes
`@VERSION@`, `@SUITE@`, `@ARCH@`, `@INSTALLED_SIZE@`, `@PACKAGE@` and `@DATE@` into
`control` and `changelog`.

| File | Description |
| --- | --- |
| `control` | Required. Full control template — this is where `Depends`, `Section`, `Homepage`, `Description` and friends go. Must contain `@VERSION@`. |
| `changelog` | Installed as `changelog.Debian.gz` (Debian Policy §12.7). |
| `copyright` | Installed to `usr/share/doc/<pkg>/` (Debian Policy §12.7). |
| `postinst`, `preinst`, `prerm`, `postrm` | Optional maintainer scripts. |
| `control.<produce>` | Optional per-output control file for packages with multiple `produces`. |
| `lintian-overrides` | Optional. |

Use `packages/alacritty/debian/` as a reference.

## Adding a package

1. Add an entry to `versions.yml` with the short upstream name. This is the package
   registry — a directory without an entry here is invisible to the build workflow.
2. Add an entry to `update-sources.yml` so the daily check can bump it.
3. Create `packages/<name>/Dockerfile`, `packages/<name>/package.yml` and
   `packages/<name>/debian/`.
4. Run `make lint PKG=<name>` and `make build PKG=<name>`.
5. Push. The workflow detects the new entry and builds it automatically.

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
