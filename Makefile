# ============================================================================
# MSP iOS SDK — Developer Workflow Makefile
# ============================================================================
# Usage:
#   make setup          Install dependencies (bundle + pod + workspace)
#   make open           Switch to dev mode and open Xcode workspace
#   make test           Run Swift unit tests
#   make validate       Quick CI validation
#   make rtt            Round-trip test (full target-switching compatibility)
#   make ci             Full CI pipeline
#   make fetch-credentials  Fetch ASC keys from private credentials repo
#   make beta           Upload DemoApp to TestFlight
#   make release        Production CocoaPods release
#   make resume         Resume a failed release
#   make freeze         Weekly code freeze (NB_VERSION= required)
#   make unfreeze       Post-release cleanup (NB_VERSION= required)
#   make sync           Sync agent rules across Claude/Cursor/Codex/Gemini
#   make clean          Clean DerivedData and Pods
# ============================================================================

.PHONY: setup open test validate rtt ci fetch-credentials beta beta-dry release release-prerelease resume freeze unfreeze clean sync validate-sync help

SHELL := /bin/bash
ROOT_DIR := $(shell pwd)
SCRIPTS := $(ROOT_DIR)/Scripts
WORKSPACE := msp-ios-sdk.xcworkspace

# Default target
help:
	@echo "MSP iOS SDK — Developer Workflow"
	@echo ""
	@echo "  make setup              Install dependencies (bundle + pod + workspace)"
	@echo "  make open               Switch pods-dev and open Xcode workspace"
	@echo "  make test               Run Swift unit tests (MSPDemoApp scheme)"
	@echo "  make validate           Quick CI validation"
	@echo "  make rtt                Round-trip test (target-switching compatibility)"
	@echo "  make ci                 Full CI pipeline"
	@echo "  make fetch-credentials  Fetch ASC keys from private credentials repo"
	@echo "  make beta               Upload DemoApp to TestFlight (requires ASC credentials)"
	@echo "  make beta-dry           Archive + export only, no upload"
	@echo "  make freeze             Weekly code freeze (NB_VERSION= required)"
	@echo "  make unfreeze           Post-release cleanup (NB_VERSION= required)"
	@echo "  make release            Production release (VERSION= NOTES= required)"
	@echo "  make release-prerelease Prerelease publication (VERSION=X.Y.Z-suffix required)"
	@echo "  make resume             Resume failed release (VERSION= required)"
	@echo "  make sync               Sync agent rules across Claude/Cursor/Codex/Gemini"
	@echo "  make clean              Clean DerivedData and Pods"
	@echo ""
	@echo "Examples:"
	@echo "  make release VERSION=1.2.0 NOTES=\"Fix crash in ad loading\""
	@echo "  make resume VERSION=1.2.0"
	@echo "  make beta"

# --------------------------------------------------------------------------
# setup — Install all dependencies
# --------------------------------------------------------------------------
setup:
	git config core.hooksPath .githooks
	bundle install
	pod install
	$(SCRIPTS)/workspace/update.sh

# --------------------------------------------------------------------------
# open — Switch to pods-dev mode and open workspace
# --------------------------------------------------------------------------
open:
	$(SCRIPTS)/switch-target.sh pods-dev
	open $(WORKSPACE)

# --------------------------------------------------------------------------
# test — Run Swift unit tests
# --------------------------------------------------------------------------
test:
	set -o pipefail && xcodebuild test \
		-workspace $(WORKSPACE) \
		-scheme MSPDemoAppTests \
		-destination 'platform=iOS Simulator,name=iPhone 16e' \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		| xcpretty || true

# --------------------------------------------------------------------------
# validate — Quick CI validation
# --------------------------------------------------------------------------
validate:
	$(SCRIPTS)/ci/ci-validate-quick.sh

# --------------------------------------------------------------------------
# rtt — Round-trip test
# --------------------------------------------------------------------------
rtt:
	$(SCRIPTS)/target-switching/round-trip-test.sh

# --------------------------------------------------------------------------
# ci — Full CI pipeline
# --------------------------------------------------------------------------
ci:
	$(SCRIPTS)/ci/ci-pipeline.sh

# --------------------------------------------------------------------------
# fetch-credentials — Pull ASC keys from private credentials repo
# --------------------------------------------------------------------------
# Usage: make fetch-credentials
# Optional: CREDENTIALS_REPO_URL=git@github.com:Org/repo.git make fetch-credentials
fetch-credentials:
	$(SCRIPTS)/testflight/fetch-credentials.sh

# --------------------------------------------------------------------------
# beta — TestFlight upload via fastlane
# --------------------------------------------------------------------------
beta:
	$(SCRIPTS)/testflight/deploy.sh

beta-dry:
	$(SCRIPTS)/testflight/deploy.sh --dry-run

# --------------------------------------------------------------------------
# release — Production CocoaPods release
# --------------------------------------------------------------------------
# Usage: make release VERSION=1.2.0 NOTES="Release notes here"
# Optional: EXTRA_FLAGS="--skip-preflight --dry-run --verbose"
VERSION ?=
NOTES ?=
EXTRA_FLAGS ?=

release:
ifndef VERSION
	$(error VERSION is required. Usage: make release VERSION=1.2.0 NOTES="Release notes")
endif
	$(SCRIPTS)/msp-release.sh run $(VERSION) \
		$(if $(NOTES),--release-notes "$(NOTES)") \
		$(EXTRA_FLAGS)

# --------------------------------------------------------------------------
# release-prerelease — Publish a prerelease (X.Y.Z-suffix) for testing only
# --------------------------------------------------------------------------
# Usage: make release-prerelease VERSION=1.2.0-rc.1 NOTES="RC for testing"
# The MSP_PRERELEASE=1 flag enforces the version suffix mutex check and
# enables the Slack ⚠️ prerelease banner. NOT for production apps.
release-prerelease:
ifndef VERSION
	$(error VERSION is required. Usage: make release-prerelease VERSION=1.2.0-rc.1 NOTES="RC")
endif
	MSP_PRERELEASE=1 $(SCRIPTS)/msp-release.sh run $(VERSION) \
		$(if $(NOTES),--release-notes "$(NOTES)") \
		$(EXTRA_FLAGS)

# --------------------------------------------------------------------------
# resume — Resume a failed release
# --------------------------------------------------------------------------
# Usage: make resume VERSION=1.2.0
# Optional: EXTRA_FLAGS="--skip-preflight --verbose"
resume:
ifndef VERSION
	$(error VERSION is required. Usage: make resume VERSION=1.2.0)
endif
	$(SCRIPTS)/msp-release.sh resume $(VERSION) \
		$(EXTRA_FLAGS)

# --------------------------------------------------------------------------
# freeze — Weekly code freeze
# --------------------------------------------------------------------------
# Usage: make freeze NB_VERSION=26.18.0
NB_VERSION ?=
KEEP_BRANCH ?=

freeze:
ifndef NB_VERSION
	$(error NB_VERSION is required. Usage: make freeze NB_VERSION=26.18.0)
endif
	$(SCRIPTS)/freeze.sh NB_VERSION=$(NB_VERSION)

# --------------------------------------------------------------------------
# unfreeze — Post-release cleanup
# --------------------------------------------------------------------------
# Usage: make unfreeze NB_VERSION=26.18.0 [KEEP_BRANCH=1]
unfreeze:
ifndef NB_VERSION
	$(error NB_VERSION is required. Usage: make unfreeze NB_VERSION=26.18.0)
endif
	$(SCRIPTS)/unfreeze.sh NB_VERSION=$(NB_VERSION) $(if $(filter 1,$(KEEP_BRANCH)),KEEP_BRANCH=1)

# --------------------------------------------------------------------------
# sync — Sync agent rules across Claude/Cursor/Codex/Gemini
# --------------------------------------------------------------------------
sync:
	python3 $(SCRIPTS)/tools/generate-context-index.py
	python3 $(SCRIPTS)/tools/sync-agent-rules.py
	@echo "Agent sync complete. Run 'make validate-sync' to verify."

# --------------------------------------------------------------------------
# validate-sync — Validate agent sync consistency
# --------------------------------------------------------------------------
validate-sync:
	$(SCRIPTS)/tools/validate-agent-sync.sh

# --------------------------------------------------------------------------
# clean — Clean build artifacts
# --------------------------------------------------------------------------
clean:
	rm -rf ~/Library/Developer/Xcode/DerivedData/msp-ios-sdk-*
	rm -rf Pods
	@echo "Cleaned DerivedData and Pods. Run 'make setup' to reinstall."
