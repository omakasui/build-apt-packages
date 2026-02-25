# omakasui/build-apt-packages

Repository for building [APT packages](https://github.com/omakasui/apt-packages) to be distributed via Omakasui.

## Current packages

- ...

## Adding a new package

1. Add entry to `versions.yml`:
```yaml
package:
  version: "1234"
  depends_on: []
```

2. Create `packages/package/`:
   - `Dockerfile` — build environment
   - `package.yml` — runtime deps, section, description
   - `deps/.gitkeep` — keeps directory in Git

3. Push — the workflow is generic and handles new packages automatically.

## Custom dependencies

If package A depends on custom package B (also in this repo):

```yaml
package1:
  version: "1.0.0"
  depends_on: ["package1"]

package1:
  version: "2.0.0"
  depends_on: []
```

The CI downloads `package2` .deb and installs it inside the Docker build container
for `package1` before compilation starts.

## Updating a package version

Edit `versions.yml` and push to `main`. The CI builds only changed packages automatically.

```yaml
# versions.yml
package:
  version: "12345"
  depends_on: ["package_deps"]
```

```bash
git add versions.yml
git commit -m "package: bump to 12345"
git push origin main
```

Multi-package commits are supported.

## Manual rebuild (no version bump)

GitHub → Actions → **Build package** → Run workflow → enter package name.
Version is read from `versions.yml` automatically.

## Repository structure

```
build-pkg/
├── versions.yml              ← source of truth
├── build-matrix.yml          ← supported distros
├── .gitignore
└── packages/
    └── package/
        ├── Dockerfile        ← parametric: BASE_IMAGE, PACKAGE_VERSION
        ├── package.yml       ← runtime deps, metadata
        └── deps/.gitkeep     ← for custom dependencies
```