# omakasui/build-apt-packages

Builds and publishes APT packages distributed via [omakasui/apt-packages](https://github.com/omakasui/apt-packages).

## Repository layout

```
versions.yml          — source of truth for versions
build-matrix.yml      — supported distros and architectures
packages/<name>/
  Dockerfile          — build environment (receives ARG VERSION)
  package.yml         — package metadata
  deps/               — pre-downloaded custom .deb dependencies (gitkeep)
```

## Naming convention

Keys in `versions.yml` use **short upstream names** (e.g. `gum`, `alacritty`).
The installed package name may differ from the key — always check `produces[]` in `package.yml`.

Packages that are repackaged or compiled under the omakasui namespace are installed as
`omakasui-<name>` and include `Conflicts/Replaces/Provides` for the upstream package name,
so they are drop-in replacements. The GitHub release tag and the folder under `packages/`
always use the short name (e.g. `packages/gum/`, release tag `gum-0.17.0`).

## Package types

### `type: build` (default)

The Dockerfile compiles or installs files and places them under `/output/staged/`.
The workflow assembles the final `.deb` using metadata from `package.yml`.

Required `package.yml` fields: `section`, `priority`, `homepage`, `description`, `runtime_depends`, `distros`.

### `type: repackage`

The Dockerfile produces complete, ready-to-install `.deb` files directly in `/output/`.
The workflow picks them up and injects the distro and arch tags into the filename.

Required `package.yml` fields: `produces` (list of package names), `distros`.

In both cases the workflow passes `--build-arg VERSION=<version>` — declare `ARG VERSION` at the top of every Dockerfile.

## Dockerfile contract

| Type | Dockerfile must write to |
|------|--------------------------|
| `build` | `/output/staged/` (staged file tree, no DEBIAN/) |
| `repackage` | `/output/<name>_<version>_<arch>.deb` (complete debs, any arch suffix) |

`BASE_IMAGE` and `TARGETARCH` are also passed as build-args if the Dockerfile needs them.

## versions.yml

```yaml
# Keys are short upstream names — do NOT use the omakasui- prefix here.
# The installed package name is determined by produces[] in package.yml.
package-name:
  version: "1.2.3"
  depends_on: []          # list of other packages in this repo required at build time
```

Pushing a change here triggers a build for the affected packages only.
Multi-package commits are supported.

## Adding a package

1. Add an entry to `versions.yml` using the short upstream name.
2. Create `packages/<name>/Dockerfile` and `packages/<name>/package.yml`.
3. If the installed package should be `omakasui-<name>`, set `produces: [omakasui-<name>]` in `package.yml`
   and have the Dockerfile rename the package accordingly.
4. Push — the workflow detects the new entry automatically.

## Custom dependencies

List sibling packages in `depends_on`. The workflow downloads their release assets and places them in `packages/<name>/deps/` before the Docker build starts, so the Dockerfile can `COPY deps/ /deps/` and install them.

## Manual rebuild

GitHub > Actions > **Build package** > Run workflow > enter the short package name (e.g. `gum`, not `omakasui-gum`).
Version is always read from `versions.yml`.