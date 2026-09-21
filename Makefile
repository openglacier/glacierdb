VERSION ?= dev
CODENAME ?= development

# GlacierDB distribution profile.
#
# GlacierDB is a distribution built on top of openglacier-core.
# The distribution enables a fixed production profile:
#   database, auth, events and CLI/TUI support.
#
# The core remains responsible for the database engine and runtime logic.
FEATURES := database,auth,events,cli-tui
CARGO_FEATURE_FLAGS := --no-default-features --features "$(FEATURES)"

# CPU variant.
#
# generic : x86-64 baseline on x86_64; no CPU override on other architectures
# v3      : x86-64-v3, accepted only on x86_64
VARIANT ?= generic
HOST_ARCH := $(shell uname -m)

# CUDA static library discovery.
#
# CUDA is not enabled by the default GlacierDB profile.
# This detection remains available for future CUDA-enabled distribution builds.
CUDA_NATIVE_LIB_DIR ?= $(shell \
	multiarch="$$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || cc -dumpmachine 2>/dev/null || true)"; \
	for dir in \
		"$${multiarch:+/usr/lib/$$multiarch}" \
		"$(if $(filter x86_64,$(HOST_ARCH)),/usr/lib/x86_64-linux-gnu,)" \
		"/usr/local/cuda/lib64" \
		"/usr/local/cuda/targets/$(HOST_ARCH)-linux/lib"; do \
		if [ -n "$$dir" ] && \
		   [ -f "$$dir/libcudart_static.a" ] && \
		   [ -f "$$dir/libcublas_static.a" ] && \
		   [ -f "$$dir/libcublasLt_static.a" ] && \
		   [ -f "$$dir/libculibos.a" ]; then \
			printf '%s' "$$dir"; \
			break; \
		fi; \
	done)

# Cargo commands.
FORMAT := cargo fmt --all
CHECK := cargo check
TEST := cargo test
CLIP := cargo clippy --all-targets
TEST_RELEASE := cargo test --release

# Production package.
PACKAGE_NAME := glacierdb-$(VERSION).tar.gz
PACKAGE_DIR := dist-package

# Public GitHub repository.
#
# Override when needed:
#   make publish PUBLIC_REPO=git@github.com:my-org/glacierdb.git
#
PUBLIC_REPO ?= git@github.com:openglacier/glacierdb.git
PUBLIC_BRANCH ?= main

# Temporary public export.
#
# This directory is deliberately outside the source tree.
# It contains ONLY the files selected by the publish target.
PUBLIC_EXPORT ?= /tmp/glacierdb-public

.PHONY: help version build-config check test checktest \
        install-build-deps install-rustup install-nightly install-debian-deps \
        clippy audit build package publish release \
        test-cli clean distclean

help: ## Outputs this help screen
	@awk 'BEGIN {FS = ":.*?## "}; /^[a-zA-Z0-9_.-]+:.*?## / {printf "  \033[32m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

version: ## Show GlacierDB package version
	@echo "glacierdb $(VERSION) ($(CODENAME))"

build-config: ## Show GlacierDB release build configuration
	@echo "VERSION=$(VERSION)"
	@echo "CODENAME=$(CODENAME)"
	@echo "FEATURES=$(FEATURES)"
	@echo "VARIANT=$(VARIANT)"
	@echo "HOST_ARCH=$(HOST_ARCH)"
	@echo "CORE_PACKAGE=openglacier-core"
	@echo "CORE_FEATURES=$(FEATURES)"
	@case "$(FEATURES)" in \
		*cuda*) echo "CUDA_NATIVE_LIB_DIR=$(if $(CUDA_NATIVE_LIB_DIR),$(CUDA_NATIVE_LIB_DIR),<not detected>)" ;; \
	esac

check: ## Format and check code
	@$(FORMAT)
	@$(CHECK)

test: ## Run tests
	@$(TEST)

checktest: check test ## Format, check and test

install-build-deps: ## Show required system build dependencies
	@echo "Required system dependencies:"
	@echo "  Debian / Ubuntu: libssl-dev pkg-config"
	@echo "  Native builds may also require clang and libclang-dev"

install-rustup: ## Install/update Rustup stable
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
	. "$$HOME/.cargo/env" && rustup update && rustup default stable

install-nightly: ## Install Rust nightly with Rustup
	rustup toolchain install nightly
	rustup component add rust-src --toolchain nightly

install-debian-deps: ## Install Debian / Ubuntu build dependencies
	sudo apt update
	sudo apt install -y libssl-dev pkg-config

clippy: ## Run Clippy
	@$(CLIP)

audit: ## Audit dependencies using cargo-audit
	cargo audit

build: ## Build GlacierDB release binaries
	@set -eu; \
	variant_rustflags=""; \
	case "$(VARIANT)" in \
		generic) \
			if [ "$(HOST_ARCH)" = "x86_64" ]; then \
				variant_rustflags="-C target-cpu=x86-64"; \
			fi; \
			;; \
		v3) \
			if [ "$(HOST_ARCH)" != "x86_64" ]; then \
				echo "ERROR: VARIANT=v3 requires x86_64 (host: $(HOST_ARCH))"; \
				exit 1; \
			fi; \
			variant_rustflags="-C target-cpu=x86-64-v3"; \
			;; \
		*) \
			echo "ERROR: VARIANT must be 'generic' or 'v3' (got: $(VARIANT))"; \
			exit 1; \
			;; \
	esac; \
	\
	build_rustflags="$${RUSTFLAGS:-}"; \
	if [ -n "$$variant_rustflags" ]; then \
		build_rustflags="$${build_rustflags:+$$build_rustflags }$$variant_rustflags"; \
	fi; \
	\
	echo "Building GlacierDB $(VERSION) ($(CODENAME))"; \
	echo "  features: $(FEATURES)"; \
	echo "  variant : $(VARIANT)"; \
	\
	if [ -n "$$build_rustflags" ]; then \
		echo "  rustflags: $$build_rustflags"; \
		RUSTFLAGS="$$build_rustflags" \
			cargo build --release --bins $(CARGO_FEATURE_FLAGS); \
	else \
		echo "  rustflags: <none>"; \
		cargo build --release --bins $(CARGO_FEATURE_FLAGS); \
	fi

package: build ## Create production runtime archive
	rm -rf $(PACKAGE_DIR)
	mkdir -p $(PACKAGE_DIR)/bin

	@test -x target/release/glacierdb || { \
		echo "ERROR: target/release/glacierdb was not built."; \
		exit 1; \
	}

	@test -x target/release/glaciercli || { \
		echo "ERROR: target/release/glaciercli was not built."; \
		exit 1; \
	}

	cp target/release/glacierdb $(PACKAGE_DIR)/bin/
	cp target/release/glaciercli $(PACKAGE_DIR)/bin/

	printf 'VERSION=%s\nCODENAME=%s\n' \
		'$(VERSION)' \
		'$(CODENAME)' \
		> $(PACKAGE_DIR)/VERSION

	tar czf $(PACKAGE_NAME) -C $(PACKAGE_DIR) .

	@echo "Created $(PACKAGE_NAME)"

publish: ## Publish the current og-db snapshot to the public GitHub repository
	@set -eu; \
	\
	echo "==> Public repository: $(PUBLIC_REPO)"; \
	echo "==> Public branch: $(PUBLIC_BRANCH)"; \
	echo "==> Temporary export: $(PUBLIC_EXPORT)"; \
	\
	# The source repository is a mono-repo. Only the current og-db tree is \
	# exported; no git history from the mono-repo is pushed. \
	if ! git diff --quiet -- . || ! git diff --cached --quiet -- .; then \
		echo "ERROR: og-db contains uncommitted changes."; \
		echo "Commit your changes before publishing."; \
		exit 1; \
	fi; \
	\
	echo "==> Source commit:"; \
	git show --no-patch --format='    %H%n    %s' HEAD; \
	\
	echo "==> Preparing temporary public repository"; \
	rm -rf "$(PUBLIC_EXPORT)"; \
	git clone "$(PUBLIC_REPO)" "$(PUBLIC_EXPORT)"; \
	\
	cd "$(PUBLIC_EXPORT)"; \
	git checkout -B "$(PUBLIC_BRANCH)"; \
	\
	PREVIOUS_SOURCE_COMMIT="$$( \
		git log \
			--format='%(trailers:key=Source-Commit,valueonly)' \
			2>/dev/null \
			| sed -n '/^[0-9a-fA-F]\{7,64\}$$/ { p; q; }' \
	)"; \
	\
	if [ -z "$$PREVIOUS_SOURCE_COMMIT" ]; then \
		PREVIOUS_SOURCE_COMMIT="$$( \
			git log --format='%s' 2>/dev/null \
			| sed -n \
				-e 's/^Mirror GlacierDB v[^ ]* from platform \([0-9a-fA-F]\{7,64\}\)$$/\1/p' \
				-e 's/^Mirror GlacierDB from platform \([0-9a-fA-F]\{7,64\}\)$$/\1/p' \
			| head -n 1 \
		)"; \
	fi; \
	\
	if [ -n "$$PREVIOUS_SOURCE_COMMIT" ]; then \
		echo "==> Previous source commit: $$PREVIOUS_SOURCE_COMMIT"; \
	else \
		echo "==> No previous source commit found."; \
	fi; \
	\
	cd "$(CURDIR)"; \
	\
	echo "==> Removing previous public contents"; \
	find "$(PUBLIC_EXPORT)" \
		-mindepth 1 \
		-maxdepth 1 \
		! -name .git \
		-exec rm -rf {} +; \
	\
	echo "==> Copying selected GlacierDB files"; \
	\
	cp Cross.toml "$(PUBLIC_EXPORT)/"; \
	cp Cargo.toml "$(PUBLIC_EXPORT)/"; \
	\
	if [ -f Cargo.lock ]; then \
		cp Cargo.lock "$(PUBLIC_EXPORT)/"; \
	fi; \
	\
	if [ -f LICENSE ]; then \
		cp LICENSE "$(PUBLIC_EXPORT)/"; \
	fi; \
	\
	if [ -f README.md ]; then \
		cp README.md "$(PUBLIC_EXPORT)/"; \
	fi; \
	\
	if [ -f Makefile ]; then \
		cp Makefile "$(PUBLIC_EXPORT)/"; \
	fi; \
	\
	if [ -f install.sh ]; then \
		cp install.sh "$(PUBLIC_EXPORT)/"; \
	fi; \
	\
	if [ -d src ]; then \
		cp -a src "$(PUBLIC_EXPORT)/"; \
	fi; \
	\
	if [ -d github-static ]; then \
		echo "==> Copying static branding"; \
		cp -a github-static "$(PUBLIC_EXPORT)/"; \
	fi; \
	\
	if [ -d public-github/.github ]; then \
		echo "==> Copying GitHub workflows"; \
		cp -a public-github/.github "$(PUBLIC_EXPORT)/"; \
	fi; \
	\
	echo "==> Determining GlacierDB version"; \
	GLACIERDB_VERSION="$$( \
		sed -n \
			'/^\[package\]/,/^\[/s/^version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
			Cargo.toml \
			| head -1 \
	)"; \
	\
	if [ -z "$$GLACIERDB_VERSION" ]; then \
		echo "ERROR: unable to determine version from Cargo.toml"; \
		rm -rf "$(PUBLIC_EXPORT)"; \
		exit 1; \
	fi; \
	\
	echo "==> GlacierDB version: $$GLACIERDB_VERSION"; \
	\
	printf '%s\n' \
		'/target/' \
		'*.tar.gz' \
		'*.txt' \
		'/data/' \
		'/dist/' \
		'/dist-package/' \
		'bootstrap-password' \
		'.env' \
		'.env.*' \
		> "$(PUBLIC_EXPORT)/.gitignore"; \
	\
	echo "==> Checking exported files"; \
	\
	if find "$(PUBLIC_EXPORT)" \
		-path "$(PUBLIC_EXPORT)/.git" -prune -o \
		-type f \( \
			-name '*password*' -o \
			-name '*.pem' -o \
			-name '*.key' -o \
			-name '.env' -o \
			-name '.env.*' -o \
			-name 'after*.txt' \
		\) -print \
		| grep -q .; then \
		echo "ERROR: potentially sensitive file found in public export."; \
		rm -rf "$(PUBLIC_EXPORT)"; \
		exit 1; \
	fi; \
	\
	if find "$(PUBLIC_EXPORT)" \
		-path "$(PUBLIC_EXPORT)/.git" -prune -o \
		-type f \
		-size +20M \
		-print \
		| grep -q .; then \
		echo "ERROR: file larger than 20 MB found in public export."; \
		rm -rf "$(PUBLIC_EXPORT)"; \
		exit 1; \
	fi; \
	\
	echo "==> Export contents:"; \
	find "$(PUBLIC_EXPORT)" \
		-path "$(PUBLIC_EXPORT)/.git" -prune -o \
		-type f \
		-print \
		| sed "s#^$(PUBLIC_EXPORT)/##" \
		| sort; \
	\
	echo "==> Committing public snapshot"; \
	cd "$(PUBLIC_EXPORT)"; \
	git add -A; \
	\
	if git diff --cached --quiet; then \
		echo "==> No public changes to publish."; \
	else \
		SOURCE_COMMIT="$$(git -C "$(CURDIR)" rev-parse HEAD)"; \
		SOURCE_COMMIT_SHORT="$$(git -C "$(CURDIR)" rev-parse --short HEAD)"; \
		COMMIT_MESSAGE="$$(mktemp)"; \
		COMMIT_LIST="$$(mktemp)"; \
		\
		if [ -n "$$PREVIOUS_SOURCE_COMMIT" ]; then \
			if ! git -C "$(CURDIR)" \
				cat-file -e \
				"$$PREVIOUS_SOURCE_COMMIT^{commit}" \
				2>/dev/null; then \
				echo "ERROR: previous source commit $$PREVIOUS_SOURCE_COMMIT is not available in the source repository."; \
				rm -f "$$COMMIT_MESSAGE" "$$COMMIT_LIST"; \
				rm -rf "$(PUBLIC_EXPORT)"; \
				exit 1; \
			fi; \
			\
			if ! git -C "$(CURDIR)" \
				merge-base \
				"$$PREVIOUS_SOURCE_COMMIT" \
				"$$SOURCE_COMMIT" \
				>/dev/null 2>&1; then \
				echo "ERROR: previous source commit $$PREVIOUS_SOURCE_COMMIT and HEAD have no common ancestor."; \
				rm -f "$$COMMIT_MESSAGE" "$$COMMIT_LIST"; \
				rm -rf "$(PUBLIC_EXPORT)"; \
				exit 1; \
			fi; \
			\
			echo "==> Collecting source commits affecting og-db"; \
			git -C "$(CURDIR)" log \
				--reverse \
				--full-history \
				--right-only \
				--cherry-pick \
				--format='- `%h` %s' \
				"$$PREVIOUS_SOURCE_COMMIT...$$SOURCE_COMMIT" \
				-- \
				Cargo.toml \
				Cargo.lock \
				src \
				Makefile \
				install.sh \
				':(top,glob)*.md' \
				LICENSE \
				github-static \
				public-github/.github \
				> "$$COMMIT_LIST"; \
		else \
			echo "==> First tracked public publication."; \
			git -C "$(CURDIR)" show \
				-s \
				--format='- `%h` %s' \
				"$$SOURCE_COMMIT" \
				> "$$COMMIT_LIST"; \
		fi; \
		\
		COMMIT_COUNT="$$(wc -l < "$$COMMIT_LIST" | tr -d '[:space:]')"; \
		echo "==> Source commits selected: $$COMMIT_COUNT"; \
		\
		{ \
			printf \
				'Mirror GlacierDB v%s from platform %s\n\n' \
				"$$GLACIERDB_VERSION" \
				"$$SOURCE_COMMIT_SHORT"; \
			\
			printf 'Integrated source commits:\n'; \
			\
			if [ -s "$$COMMIT_LIST" ]; then \
				cat "$$COMMIT_LIST"; \
			else \
				printf '%s\n' '- No matching source commits found.'; \
			fi; \
			\
			printf '\nSource-Commit: %s\n' "$$SOURCE_COMMIT"; \
		} > "$$COMMIT_MESSAGE"; \
		\
		echo "==> Commit message:"; \
		echo; \
		cat "$$COMMIT_MESSAGE"; \
		echo; \
		\
		git commit -F "$$COMMIT_MESSAGE"; \
		rm -f "$$COMMIT_MESSAGE" "$$COMMIT_LIST"; \
		\
		echo "==> Pushing public branch"; \
		git push origin "$(PUBLIC_BRANCH)"; \
		\
		echo "==> GlacierDB public repository updated successfully."; \
	fi; \
	\
	rm -rf "$(PUBLIC_EXPORT)"

release: ## Publish GlacierDB and create the version tag in the public repository
	@set -eu; \
	\
	if ! git diff --quiet -- . || ! git diff --cached --quiet -- .; then \
		echo "ERROR: og-db contains uncommitted changes."; \
		echo "Commit your changes before creating a release."; \
		exit 1; \
	fi; \
	\
	GLACIERDB_VERSION="$$( \
		sed -n \
			'/^\[package\]/,/^\[/s/^version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
			Cargo.toml \
			| head -1 \
	)"; \
	\
	if [ -z "$$GLACIERDB_VERSION" ]; then \
		echo "ERROR: unable to determine version from Cargo.toml."; \
		exit 1; \
	fi; \
	\
	case "$$GLACIERDB_VERSION" in \
		dev|development|0.0.0) \
			echo "ERROR: release requires a real version in Cargo.toml."; \
			exit 1; \
			;; \
	esac; \
	\
	TAG="v$$GLACIERDB_VERSION"; \
	\
	echo "==> GlacierDB version: $$GLACIERDB_VERSION"; \
	echo "==> Release tag: $$TAG"; \
	echo "==> Public repository: $(PUBLIC_REPO)"; \
	\
	if git ls-remote \
		--exit-code \
		--tags \
		"$(PUBLIC_REPO)" \
		"refs/tags/$$TAG" \
		>/dev/null 2>&1; then \
		echo "ERROR: tag $$TAG already exists on the public repository."; \
		echo "Bump the version in Cargo.toml before creating another release."; \
		exit 1; \
	fi; \
	\
	echo "==> Publishing GlacierDB source"; \
	$(MAKE) publish; \
	\
	RELEASE_DIR="$$(mktemp -d)"; \
	trap 'rm -rf "$$RELEASE_DIR"' EXIT INT TERM; \
	\
	echo "==> Cloning published repository"; \
	git clone \
		--branch "$(PUBLIC_BRANCH)" \
		--single-branch \
		"$(PUBLIC_REPO)" \
		"$$RELEASE_DIR"; \
	\
	cd "$$RELEASE_DIR"; \
	\
	PUBLIC_VERSION="$$( \
		sed -n \
			'/^\[package\]/,/^\[/s/^version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
			Cargo.toml \
			| head -1 \
	)"; \
	\
	if [ "$$PUBLIC_VERSION" != "$$GLACIERDB_VERSION" ]; then \
		echo "ERROR: public Cargo.toml version does not match source version."; \
		echo "Source version: $$GLACIERDB_VERSION"; \
		echo "Public version: $$PUBLIC_VERSION"; \
		exit 1; \
	fi; \
	\
	echo "==> Public release commit:"; \
	git show \
		--no-patch \
		--format='    %H%n    %s' \
		HEAD; \
	\
	echo "==> Creating annotated tag $$TAG"; \
	git tag \
		-a "$$TAG" \
		-m "Release $$TAG"; \
	\
	echo "==> Pushing $$TAG"; \
	git push origin "$$TAG"; \
	\
	echo; \
	echo "==> GlacierDB release $$TAG published successfully."; \
	echo "==> GitHub now contains only the exported GlacierDB tree."

test-cli: ## Basic GlacierCLI query tests
	cargo run --bin glaciercli -- 'from users'
	cargo run --bin glaciercli -- 'from users | where age >= 18'
	cargo run --bin glaciercli -- 'from users | set active = true'
	cargo run --bin glaciercli -- 'from users | insert {"a": 1}'
	cargo run --bin glaciercli -- 'on users | lookup workspace | into ws | end'
	cargo run --bin glaciercli -- 'on sales | pivot | rows region | columns month | values amount | aggregate sum | end'

clean: ## Remove generated packaging files
	rm -rf $(PACKAGE_DIR) $(PACKAGE_NAME)

distclean: clean ## Cargo clean
	cargo clean