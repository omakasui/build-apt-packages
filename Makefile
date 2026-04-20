SHELL   := /bin/bash
.DEFAULT_GOAL := help

PKG     ?=
DISTRO  ?=
ARCH    ?= amd64
SCRIPTS := scripts

_require_pkg = $(if $(PKG),,$(error PKG is required. Example: make $@ PKG=fzf))

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*##"}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: ## Build a package locally (PKG= required, DISTRO= ARCH= optional)
	$(call _require_pkg)
	@$(SCRIPTS)/build-local.sh $(PKG) \
		$(if $(DISTRO),--distro $(DISTRO)) \
		$(if $(filter-out amd64,$(ARCH)),--arch $(ARCH))

.PHONY: lint
lint: ## Validate package definitions (PKG= optional, omit for all)
	@$(SCRIPTS)/lint-package.sh $(PKG)

.PHONY: list
list: ## List all packages with their versions
	@yq e 'to_entries | .[] | .key + "  " + .value.version' versions.yml | \
		column -t -s '  '

.PHONY: info
info: ## Show metadata for a package (PKG= required)
	$(call _require_pkg)
	@echo ""; \
	echo "Package  : $(PKG)"; \
	echo "Version  : $$(yq e '.$(PKG).version' versions.yml)"; \
	echo "Type     : $$(yq e '.type // "build"' packages/$(PKG)/package.yml)"; \
	echo "Arch     : $$(yq e '.arch // "any"' packages/$(PKG)/package.yml)"; \
	echo "Produces : $$(yq e '.produces // [] | join(", ")' packages/$(PKG)/package.yml)"; \
	echo "Distros  : $$(yq e '.distros // [] | join(", ")' packages/$(PKG)/package.yml)"; \
	echo "Deps     : $$(yq e '.$(PKG).depends_on // [] | join(", ")' versions.yml)"; \
	echo "Homepage : $$(yq e '.homepage // ""' packages/$(PKG)/package.yml)"; \
	echo ""

.PHONY: shell
shell: ## Open an interactive shell in the build container (PKG= required, DISTRO= ARCH= optional)
	$(call _require_pkg)
	@set -e; \
	VERSION=$$(yq e '.$(PKG).version' versions.yml); \
	DISTRO_VAL=$${DISTRO:-$$(yq e '.distros | keys | .[0]' build-matrix.yml)}; \
	BASE=$$(yq e ".distros.$${DISTRO_VAL}.base_image" build-matrix.yml); \
	IMAGE="omakasui-build-$(PKG):local"; \
	echo "Building image (if not cached)..."; \
	docker buildx build \
		--platform "linux/$(ARCH)" \
		--load \
		--build-arg "BASE_IMAGE=$${BASE}" \
		--build-arg "VERSION=$${VERSION}" \
		--tag "$${IMAGE}" \
		"packages/$(PKG)/"; \
	echo "Opening shell in $${IMAGE}..."; \
	docker run --rm -it --platform "linux/$(ARCH)" "$${IMAGE}" /bin/bash

.PHONY: clean
clean: ## Remove local build output (output/)
	@rm -rf output/
	@echo "Cleaned output/"

.PHONY: clean-images
clean-images: ## Remove all omakasui-build-* Docker images
	@images=$$(docker images --format '{{.Repository}}:{{.Tag}}' | grep '^omakasui-build-' || true); \
	if [[ -n "$$images" ]]; then \
		echo "$$images" | xargs docker rmi; \
	else \
		echo "No omakasui-build images found."; \
	fi
