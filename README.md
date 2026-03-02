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

## Package types

### `type: build` (default)

The Dockerfile compiles or installs files and places them under `/output/staged/`.
The workflow assembles the final `.deb` using metadata from `package.yml`.

Required `package.yml` fields: `section`, `priority`, `homepage`, `description`, `runtime_depends`, `distros`.

### `type: repackage`

The Dockerfile produces complete, ready-to-install `.deb` files directly in `/output/`.
The workflow picks them up and injects the distro tag into the filename.

Required `package.yml` fields: `produces` (list of package names), `distros`.

In both cases the workflow passes `--build-arg VERSION=<version>` — declare `ARG VERSION` at the top of every Dockerfile.

## Dockerfile contract

| Type | Dockerfile must write to |
|------|--------------------------|
| `build` | `/output/staged/` (staged file tree, no DEBIAN/) |
| `repackage` | `/output/<name>_<version>_all.deb` (complete debs) |

`BASE_IMAGE` is also passed as a build-arg if the Dockerfile needs it.

## versions.yml

```yaml
# Package names are top-level keys — do NOT nest under a parent key.
package-name:
  version: "1.2.3"
  depends_on: []          # list of other packages in this repo required at build time
```

Pushing a change here triggers a build for the affected packages only.
Multi-package commits are supported.

## Adding a package

1. Add an entry to `versions.yml`.
2. Create `packages/<name>/Dockerfile` and `packages/<name>/package.yml`.
3. Push — the workflow detects the new entry automatically.

## Custom dependencies

List sibling packages in `depends_on`. The workflow downloads their release assets and places them in `packages/<name>/deps/` before the Docker build starts, so the Dockerfile can `COPY deps/ /deps/` and install them.

## Manual rebuild

GitHub > Actions > **Build package** > Run workflow > enter the package name.
Version is always read from `versions.yml`.
