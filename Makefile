# Focus: the commands a human, CI and the coding agent all run.
#
#   make check            everything CI checks, before you push
#   make e2e              an isolated E2E run on the Firebase emulators
#
# See docs/self-driving/README.md.

SHELL := /bin/bash
.DEFAULT_GOAL := help

ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
FLUTTER_PACKAGES := app_ui chat notifications

.PHONY: help check check-server check-agent check-app \
	install dev-server dev-agent \
	e2e

help:
	@grep -E '^[a-z0-9-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

## ---- checks -------------------------------------------------------------

check: check-server check-agent check-app ## Run every check CI runs

check-server: ## Lint, type-check, test and build the NestJS backend
	cd server && npm ci --no-audit --no-fund
	cd server && npx eslint "{src,test}/**/*.ts"
	cd server && npx tsc --noEmit -p tsconfig.json
	cd server && npm test --silent
	cd server && npm run build

check-agent: ## Build and test the agent
	cd agent && npm ci --no-audit --no-fund
	cd agent && npm run build
	cd agent && npm test

check-app: ## Analyze and test the Flutter app and its packages
	cd app && flutter pub get
	cd app && dart format --output=none --set-exit-if-changed lib $(addprefix packages/,$(addsuffix /lib,$(FLUTTER_PACKAGES) auth api_client user))
	cd app && flutter analyze
	@for pkg in $(FLUTTER_PACKAGES); do \
		echo "== flutter test packages/$$pkg"; \
		(cd app/packages/$$pkg && flutter test) || exit 1; \
	done

## ---- local environment --------------------------------------------------

install: ## Install server, agent and app dependencies
	cd server && npm ci
	cd agent && npm ci
	cd app && flutter pub get

dev-server: ## Start the backend on the dev environment (server/.env.local)
	cd server && npm run start:local

dev-agent: ## Start the agent on the dev environment (agent/.env.local)
	cd agent && npm run start:local

## ---- end to end ---------------------------------------------------------

e2e: ## Isolated E2E run on the Firebase emulators (FLOWS=<files> to pick)
	e2e/scripts/e2e.sh $(FLOWS)
