# AI Dev Atelier Makefile
# Convenience commands for development and CI

.PHONY: all help setup install validate lint test clean pre-commit

all: test ## Run all checks (alias for test)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Verify repository structure
	bash setup.sh

install: ## Install skills and MCPs to Codex and OpenCode
	bash install.sh

validate: ## Validate all skills against Anthropic Agent Skills spec
	bash .test/scripts/validate-skills.sh

lint: ## Lint all shell scripts with shellcheck
	bash .test/scripts/lint-shell.sh

test: validate lint ## Run all tests (validate + lint)

pre-commit: ## Install pre-commit hooks
	pip install pre-commit && pre-commit install

clean: ## Clean output directories
	rm -rf .ada/
