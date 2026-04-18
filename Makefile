.DEFAULT_GOAL := help
SHELL := /bin/bash

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PROJECT := $(ROOT)/Stakka.xcodeproj
PROJECT_SPEC := $(ROOT)/project.yml

XCODEGEN ?= xcodegen
XCODEBUILD ?= xcodebuild
OPEN ?= open

SCHEME ?= Stakka
CONFIGURATION ?= Debug
DESTINATION ?= generic/platform=iOS Simulator
DERIVED_DATA ?= $(ROOT)/.derivedData

.PHONY: help check check-tools generate regenerate open build build-debug build-release clean project-clean derived-data-clean show-destinations show-settings

-include Makefile.local

# ─────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─────────────────────────────────────────────
# Setup
# ─────────────────────────────────────────────

check-tools: ## Verify required local tools are installed
	@command -v $(XCODEGEN) >/dev/null 2>&1 || { echo "xcodegen not found. Install with 'brew install xcodegen'."; exit 1; }
	@command -v $(XCODEBUILD) >/dev/null 2>&1 || { echo "xcodebuild not found. Install Xcode command line tools."; exit 1; }

check: check-tools ## Run the standard local verification pass
	@if command -v swiftlint >/dev/null 2>&1; then \
		cd "$(ROOT)" && swiftlint; \
	else \
		echo "swiftlint not installed; skipping lint"; \
	fi
	$(MAKE) build-debug DESTINATION='generic/platform=iOS Simulator'

generate: check-tools ## Generate Stakka.xcodeproj from project.yml
	rm -rf "$(ROOT)/Stakka/Stakka.xcodeproj"
	cd "$(ROOT)" && $(XCODEGEN) generate

regenerate: generate ## Alias for generate

open: generate ## Generate project if needed, then open it in Xcode
	$(OPEN) "$(PROJECT)"

# ─────────────────────────────────────────────
# Build
# ─────────────────────────────────────────────

build: generate ## Build app for the configured destination
	cd "$(ROOT)" && $(XCODEBUILD) \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination "$(DESTINATION)" \
		-derivedDataPath "$(DERIVED_DATA)" \
		build

build-debug: CONFIGURATION := Debug
build-debug: build ## Build Debug configuration for simulator

build-release: CONFIGURATION := Release
build-release: build ## Build Release configuration for simulator

show-destinations: generate ## List available xcodebuild destinations for the scheme
	cd "$(ROOT)" && $(XCODEBUILD) -showdestinations -project "$(PROJECT)" -scheme "$(SCHEME)"

show-settings: generate ## Print key effective build settings
	cd "$(ROOT)" && $(XCODEBUILD) \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-showBuildSettings

# ─────────────────────────────────────────────
# Cleanup
# ─────────────────────────────────────────────

clean: ## Remove local build artifacts created by this Makefile
	rm -rf "$(DERIVED_DATA)"

project-clean: generate ## Run xcodebuild clean for the configured scheme
	cd "$(ROOT)" && $(XCODEBUILD) \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-derivedDataPath "$(DERIVED_DATA)" \
		clean

derived-data-clean: clean ## Alias for clean
