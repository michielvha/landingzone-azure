.PHONY: build clean test run install help

BINARY_NAME=setup-azure-workload-identity
VERSION?=1.0.0
BUILD_DIR=bin

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

build: ## Build for current platform
	@echo "Building $(BINARY_NAME)..."
	@go build -ldflags "-X main.version=$(VERSION)" -o $(BINARY_NAME) .
	@echo "✅ Built: $(BINARY_NAME)"

build-all: ## Build for all platforms
	@chmod +x build.sh
	@./build.sh

clean: ## Clean build artifacts
	@rm -rf $(BUILD_DIR) $(BINARY_NAME) $(BINARY_NAME).exe
	@echo "✅ Cleaned"

test: ## Run tests
	@go test -v ./...

run: ## Run in interactive mode
	@go run main.go --interactive

run-config: ## Run with config file
	@go run main.go --config config.yaml

install: ## Install to GOPATH/bin
	@go install .
	@echo "✅ Installed to $(GOPATH)/bin/$(BINARY_NAME)"

deps: ## Download dependencies
	@go mod download
	@go mod tidy
	@echo "✅ Dependencies downloaded"

fmt: ## Format code
	@go fmt ./...
	@echo "✅ Code formatted"

lint: ## Run linter
	@golangci-lint run || echo "golangci-lint not installed"

.DEFAULT_GOAL := help
