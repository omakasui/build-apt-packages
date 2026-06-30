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
		awk 'BEGIN {FS = ":.*##"}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: ## Build a package locally  (PKG= required, DISTRO= ARCH= optional)
	$(call _require_pkg)
	@TYPE=$$(yq e '.type // "build"' packages/$(PKG)/package.yml); \
	ARGS="$(PKG) $(if $(DISTRO),--distro $(DISTRO)) $(if $(filter-out amd64,$(ARCH)),--arch $(ARCH))"; \
	if [[ "$$TYPE" == "passthrough" ]]; then \
		$(SCRIPTS)/passthrough.sh $$ARGS; \
	else \
		$(SCRIPTS)/build.sh $$ARGS; \
	fi

.PHONY: lint
lint: ## Validate package definitions  (PKG= optional)
	@$(SCRIPTS)/lint.sh $(PKG)

.PHONY: lintian
lintian: ## Run lintian on built output  (PKG= optional, requires prior 'make build')
	@$(SCRIPTS)/lint.sh $(PKG) --lintian

.PHONY: list
list: ## List all packages and versions
	@yq e 'to_entries | .[] | .key + "  " + .value.version' versions.yml | column -t -s '  '

.PHONY: info
info: ## Show package metadata  (PKG= required)
	$(call _require_pkg)
	@echo ""; \
	echo "Package  : $(PKG)"; \
	echo "Version  : $$(yq e '.$(PKG).version' versions.yml)"; \
	echo "Type     : $$(yq e '.type // "build"' packages/$(PKG)/package.yml)"; \
	echo "Arch     : $$(yq e '.arch // "any"' packages/$(PKG)/package.yml)"; \
	echo "Distros  : $$(yq e '.distros | join(", ")' packages/$(PKG)/package.yml)"; \
	echo "Deps     : $$(yq e '.$(PKG).depends_on // [] | join(", ")' versions.yml)"; \
	echo "Homepage : $$(grep '^Homepage:' packages/$(PKG)/debian/control 2>/dev/null | awk '{print $$2}')"; \
	echo ""

.PHONY: shell
shell: ## Shell into the build container  (PKG= required, DISTRO= ARCH= optional)
	$(call _require_pkg)
	@TYPE=$$(yq e '.type // "build"' packages/$(PKG)/package.yml); \
	if [[ "$$TYPE" == "passthrough" ]]; then \
		echo "Error: $(PKG) is type:passthrough — no Docker container."; exit 1; \
	fi; \
	VERSION=$$(yq e '.$(PKG).version' versions.yml); \
	DISTRO_VAL=$${DISTRO:-$$(yq e '.distros | keys | .[0]' build-matrix.yml)}; \
	BASE=$$(yq e ".distros.$${DISTRO_VAL}.base_image" build-matrix.yml); \
	IMAGE="omakasui-build-$(PKG):local"; \
	docker buildx build \
		--platform "linux/$(ARCH)" \
		--load \
		--build-arg "BASE_IMAGE=$${BASE}" \
		--build-arg "VERSION=$${VERSION}" \
		--tag "$${IMAGE}" \
		"packages/$(PKG)/"; \
	docker run --rm -it --platform "linux/$(ARCH)" "$${IMAGE}" /bin/bash

.PHONY: check-updates
check-updates: ## Check for new upstream releases and open PRs  (PKG= optional)
	@$(if $(PKG),CHECK_SINGLE_PACKAGE=$(PKG)) $(SCRIPTS)/check-updates.sh

.PHONY: clean
clean: ## Remove build output (output/)
	@rm -rf output/ && echo "Cleaned output/"

.PHONY: clean-images
clean-images: ## Remove all omakasui-build-* Docker images
	@images=$$(docker images --format '{{.Repository}}:{{.Tag}}' | grep '^omakasui-build-' || true); \
	if [[ -n "$$images" ]]; then echo "$$images" | xargs docker rmi; \
	else echo "No omakasui-build images found."; fi
