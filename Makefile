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

# Simulator targets ───────────────────────────────────────────
# Override on the command line, e.g. `make run SIMULATOR='iPhone 17 Pro Max'`.
SIMULATOR ?= iPhone 17 Pro
BUNDLE_ID ?= com.stakka.app
SIM_DESTINATION = platform=iOS Simulator,name=$(SIMULATOR)
APP_PATH = $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)-iphonesimulator/$(SCHEME).app

.PHONY: help check check-tools generate regenerate open build build-debug build-release clean project-clean derived-data-clean show-destinations show-settings sim-list sim-boot sim-open sim-shutdown sim-erase sim-build sim-install sim-launch sim-stop sim-logs run debug

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
# Simulator (boot, install, run, logs)
# ─────────────────────────────────────────────

sim-list: ## List bootable iPhone / iPad simulators
	@xcrun simctl list devices available | grep -E "iPhone|iPad" | sed 's/^[[:space:]]*//'

sim-boot: ## Boot the configured simulator (no-op if already booted)
	@xcrun simctl boot "$(SIMULATOR)" 2>/dev/null || true

sim-open: sim-boot ## Boot + open Simulator.app so the screen is visible
	$(OPEN) -a Simulator

sim-shutdown: ## Shutdown the configured simulator
	-xcrun simctl shutdown "$(SIMULATOR)" 2>/dev/null

sim-erase: ## Erase content & settings on the configured simulator
	-xcrun simctl shutdown "$(SIMULATOR)" 2>/dev/null
	xcrun simctl erase "$(SIMULATOR)"

sim-build: generate ## Build the app for the concrete simulator (required before install)
	cd "$(ROOT)" && $(XCODEBUILD) \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination "$(SIM_DESTINATION)" \
		-derivedDataPath "$(DERIVED_DATA)" \
		build

sim-install: sim-build sim-boot ## Build + install the .app on the booted simulator
	xcrun simctl install "$(SIMULATOR)" "$(APP_PATH)"

sim-launch: ## Launch the installed app (returns immediately)
	xcrun simctl launch "$(SIMULATOR)" "$(BUNDLE_ID)"

sim-stop: ## Terminate the app if it is running on the simulator
	-xcrun simctl terminate "$(SIMULATOR)" "$(BUNDLE_ID)" 2>/dev/null

run: sim-open sim-install ## One-shot: boot + build + install + launch with stdout/stderr streamed
	-xcrun simctl terminate "$(SIMULATOR)" "$(BUNDLE_ID)" 2>/dev/null
	xcrun simctl launch --console-pty "$(SIMULATOR)" "$(BUNDLE_ID)"

debug: sim-open sim-install ## Launch waiting for a debugger to attach (Xcode → Debug → Attach to Process)
	-xcrun simctl terminate "$(SIMULATOR)" "$(BUNDLE_ID)" 2>/dev/null
	xcrun simctl launch --wait-for-debugger "$(SIMULATOR)" "$(BUNDLE_ID)"

sim-logs: ## Stream OS logs filtered to the Stakka process from the booted simulator
	xcrun simctl spawn "$(SIMULATOR)" log stream --level debug \
		--predicate 'processImagePath ENDSWITH "/$(SCHEME)"'

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
