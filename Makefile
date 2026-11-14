# organize-my-iphone: developer shortcuts.
#
# Run `make` (or `make help`) to list every target. Each target is a thin wrapper around
# SwiftPM, so anything here can also be run by hand; docs/development.md shows the
# equivalent commands.
#
# To add a target to the help screen, put `## description` after its name.
# To start a new group in the help screen, add a line beginning with `##@ Group name`.

.DEFAULT_GOAL := help
SHELL := /bin/bash

# ---- Settings you can override on the command line, e.g. `make install PREFIX=/opt/tools` ----

# Where `make install` puts the binary (in $(PREFIX)/bin). The default needs no sudo;
# building as root would leave root-owned files in .build.
PREFIX ?= $(HOME)/.local
# Arguments passed to the tool by `make run`, e.g. `make run ARGS="apply folder-board --dry-run"`.
ARGS ?= --help
# Folder `make demo` writes its scan, plans and preview to. Empty means a fresh temporary folder.
DEMO_WORKSPACE ?=

BINARY := organize-my-iphone
SWIFT_PATHS := Sources Tests Package.swift

.PHONY: help build release install uninstall clean test demo check lint format doctor run

##@ General

help: ## Show this help
	@awk 'BEGIN { FS = ":.*## "; printf "\nUsage:\n  make \033[36m<target>\033[0m [VARIABLE=value]\n" } \
		/^##@ / { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } \
		/^[a-zA-Z0-9_-]+:.*## / { printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@printf "\n\033[1mVariables\033[0m\n"
	@printf "  \033[36m%-15s\033[0m %s\n" "PREFIX" "Install location for 'make install' (now: $(PREFIX))"
	@printf "  \033[36m%-15s\033[0m %s\n" "ARGS" "Arguments for 'make run' (now: $(ARGS))"
	@printf "  \033[36m%-15s\033[0m %s\n" "DEMO_WORKSPACE" "Output folder for 'make demo' (default: a temporary folder)"
	@printf "\nExamples:\n"
	@printf "  make check\n"
	@printf "  make run ARGS=\"run --open\"\n"
	@printf "  make demo DEMO_WORKSPACE=/tmp/omi-demo\n\n"

##@ Build

build: ## Compile a debug build
	swift build

release: ## Compile an optimized build of the command-line tool
	swift build -c release --product $(BINARY)

install: release ## Install the tool into PREFIX/bin (default ~/.local/bin)
	install -d "$(PREFIX)/bin"
	install "$$(swift build -c release --show-bin-path)/$(BINARY)" "$(PREFIX)/bin/$(BINARY)"
	@echo "Installed $(PREFIX)/bin/$(BINARY)"

uninstall: ## Remove the installed tool from PREFIX/bin
	rm -f "$(PREFIX)/bin/$(BINARY)"

clean: ## Delete build products
	swift package clean

##@ Test

test: ## Run the unit tests
	swift test --parallel

demo: ## Run the whole pipeline against a fake iPhone (no device, model or network)
	bash scripts/demo.sh $(DEMO_WORKSPACE)

check: lint test demo ## Everything CI runs: lint, unit tests, then the demo

##@ Code style

lint: ## Report formatting problems without changing files
	swift format lint --recursive $(SWIFT_PATHS)

format: ## Reformat the Swift sources in place
	swift format --in-place --recursive $(SWIFT_PATHS)

##@ Run

doctor: ## Check cfgutil, the connected iPhone and local models
	swift run $(BINARY) doctor

run: ## Run the tool with ARGS, e.g. make run ARGS="run --open"
	swift run $(BINARY) $(ARGS)
