# FreeBSD Docker Development Environment Makefile
# Default target is help
.DEFAULT_GOAL := help

# Variables
DOCKER_USER ?= aygp-dr
IMAGE_NAME ?= freebsd
VERSION ?= 14.2-RELEASE
IMAGE = $(DOCKER_USER)/$(IMAGE_NAME):$(VERSION)
LATEST = $(DOCKER_USER)/$(IMAGE_NAME):latest
BUILD_DATE := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
VCS_REF := $(shell git rev-parse --short HEAD 2>/dev/null || echo 'unknown')
CONTAINER_NAME ?= freebsd-dev

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Phony targets
.PHONY: help all build run stop clean deps lint test audit push shell logs status validate

## help: Display this help message
help:
	@echo "$(BLUE)FreeBSD Docker Development Environment$(NC)"
	@echo "$(YELLOW)======================================$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@echo ""
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /' | column -t -s ':' | sed 's/^/  /'
	@echo ""
	@echo "$(GREEN)Variables:$(NC)"
	@echo "  DOCKER_USER    = $(DOCKER_USER)"
	@echo "  IMAGE_NAME     = $(IMAGE_NAME)"
	@echo "  VERSION        = $(VERSION)"
	@echo "  IMAGE          = $(IMAGE)"
	@echo ""
	@echo "$(GREEN)Examples:$(NC)"
	@echo "  gmake all           # Complete build and test"
	@echo "  gmake build         # Build the Docker image"
	@echo "  gmake run           # Run the container"
	@echo "  gmake audit         # Audit image size and security"
	@echo ""

## all: Complete build, test, and audit pipeline
all: deps lint build test audit
	@echo "$(GREEN)✓ Complete pipeline successful!$(NC)"

## deps: Check and install dependencies
deps:
	@echo "$(YELLOW)Checking dependencies...$(NC)"
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)✗ Docker is not installed$(NC)"; exit 1; }
	@command -v git >/dev/null 2>&1 || { echo "$(RED)✗ Git is not installed$(NC)"; exit 1; }
	@echo "$(GREEN)✓ Docker version:$(NC) $$(docker --version)"
	@echo "$(GREEN)✓ Git version:$(NC) $$(git --version)"
	@echo "$(GREEN)✓ All dependencies satisfied$(NC)"

## lint: Lint Dockerfiles and scripts
lint:
	@echo "$(YELLOW)Linting Dockerfiles and scripts...$(NC)"
	@if command -v hadolint >/dev/null 2>&1; then \
		hadolint Dockerfile || true; \
	else \
		echo "$(YELLOW)⚠ hadolint not installed, using Docker...$(NC)"; \
		docker run --rm -i hadolint/hadolint < Dockerfile || true; \
	fi
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck scripts/*.sh || true; \
	else \
		echo "$(YELLOW)⚠ shellcheck not installed, skipping shell script linting$(NC)"; \
	fi
	@echo "$(GREEN)✓ Linting complete$(NC)"

## build: Build the Docker image
build: deps
	@echo "$(YELLOW)Building Docker image: $(IMAGE)$(NC)"
	@docker build \
		--build-arg FREEBSD_VERSION=$(VERSION) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg VCS_REF=$(VCS_REF) \
		--tag $(IMAGE) \
		--tag $(LATEST) \
		--file Dockerfile \
		.
	@echo "$(GREEN)✓ Build successful$(NC)"
	@$(MAKE) --no-print-directory audit-size

## run: Run the container
run:
	@echo "$(YELLOW)Starting container: $(CONTAINER_NAME)$(NC)"
	@docker run -d \
		--name $(CONTAINER_NAME) \
		--privileged \
		--publish 2222:22 \
		--publish 5900:5900 \
		--env MEMORY=2G \
		--env CPUS=2 \
		--volume $(PWD)/workspace:/workspace:rw \
		$(IMAGE)
	@echo "$(GREEN)✓ Container started$(NC)"
	@echo "  SSH: ssh -p 2222 root@localhost"
	@echo "  VNC: vnc://localhost:5900"

## stop: Stop and remove the container
stop:
	@echo "$(YELLOW)Stopping container: $(CONTAINER_NAME)$(NC)"
	@docker stop $(CONTAINER_NAME) 2>/dev/null || true
	@docker rm $(CONTAINER_NAME) 2>/dev/null || true
	@echo "$(GREEN)✓ Container stopped$(NC)"

## clean: Clean up images and containers
clean: stop
	@echo "$(YELLOW)Cleaning up...$(NC)"
	@docker rmi $(IMAGE) 2>/dev/null || true
	@docker rmi $(LATEST) 2>/dev/null || true
	@docker system prune -f
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

## test: Test the Docker image
test:
	@echo "$(YELLOW)Testing Docker image...$(NC)"
	@echo "  Testing QEMU installation..."
	@docker run --rm $(IMAGE) qemu-system-x86_64 --version | head -n1
	@echo "  Testing entrypoint..."
	@docker run --rm $(IMAGE) ls -la /scripts/
	@echo "  Testing FreeBSD scripts..."
	@docker run --rm $(IMAGE) /scripts/health-check.sh && echo "$(GREEN)✓ Health check passed$(NC)" || echo "$(RED)✗ Health check failed$(NC)"
	@echo "$(GREEN)✓ Tests complete$(NC)"

## audit: Audit image size, layers, and security
audit: audit-size audit-layers audit-security
	@echo "$(GREEN)✓ Audit complete$(NC)"

## audit-size: Analyze image size
audit-size:
	@echo "$(YELLOW)Analyzing image size...$(NC)"
	@echo "$(BLUE)Image Size Summary:$(NC)"
	@docker images $(IMAGE) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
	@echo ""
	@if command -v dive >/dev/null 2>&1; then \
		echo "$(BLUE)Detailed size analysis with dive:$(NC)"; \
		dive --ci $(IMAGE) || true; \
	else \
		echo "$(YELLOW)Install 'dive' for detailed size analysis$(NC)"; \
	fi

## audit-layers: Analyze image layers
audit-layers:
	@echo "$(YELLOW)Analyzing image layers...$(NC)"
	@echo "$(BLUE)Layer Count:$(NC)"
	@docker history $(IMAGE) | wc -l
	@echo ""
	@echo "$(BLUE)Layer Details:$(NC)"
	@docker history --no-trunc --format "table {{.CreatedBy}}\t{{.Size}}" $(IMAGE) | head -20

## audit-security: Security scan
audit-security:
	@echo "$(YELLOW)Running security scan...$(NC)"
	@if command -v trivy >/dev/null 2>&1; then \
		trivy image $(IMAGE); \
	elif command -v grype >/dev/null 2>&1; then \
		grype $(IMAGE); \
	else \
		echo "$(YELLOW)⚠ No security scanner found (install trivy or grype)$(NC)"; \
		echo "  Try: brew install aquasecurity/trivy/trivy"; \
	fi

## validate: Validate the build environment
validate:
	@echo "$(YELLOW)Validating environment...$(NC)"
	@docker run --rm $(IMAGE) /usr/local/bin/validate-env || echo "$(RED)✗ Validation failed$(NC)"

## push: Push image to registry
push:
	@echo "$(YELLOW)Pushing to registry...$(NC)"
	@docker push $(IMAGE)
	@docker push $(LATEST)
	@echo "$(GREEN)✓ Push complete$(NC)"

## shell: Open shell in running container
shell:
	@docker exec -it $(CONTAINER_NAME) /bin/sh

## logs: Show container logs
logs:
	@docker logs -f $(CONTAINER_NAME)

## status: Show container status
status:
	@echo "$(BLUE)Container Status:$(NC)"
	@docker ps -a --filter name=$(CONTAINER_NAME) --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "$(BLUE)Image Status:$(NC)"
	@docker images $(DOCKER_USER)/$(IMAGE_NAME) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

## compose-up: Start full development stack
compose-up:
	@echo "$(YELLOW)Starting full development stack...$(NC)"
	@docker-compose -f docker-compose.full.yml up -d
	@echo "$(GREEN)✓ Development stack started$(NC)"

## compose-down: Stop full development stack
compose-down:
	@echo "$(YELLOW)Stopping development stack...$(NC)"
	@docker-compose -f docker-compose.full.yml down
	@echo "$(GREEN)✓ Development stack stopped$(NC)"

## compose-logs: Show development stack logs
compose-logs:
	@docker-compose -f docker-compose.full.yml logs -f

## info: Show detailed information
info:
	@echo "$(BLUE)FreeBSD Docker Development Environment$(NC)"
	@echo "$(YELLOW)======================================$(NC)"
	@echo ""
	@echo "$(GREEN)Repository:$(NC)"
	@echo "  URL: https://github.com/$(DOCKER_USER)/$(IMAGE_NAME)"
	@echo "  Branch: $$(git branch --show-current)"
	@echo "  Commit: $$(git rev-parse HEAD)"
	@echo ""
	@echo "$(GREEN)Image:$(NC)"
	@echo "  Name: $(IMAGE)"
	@echo "  Size: $$(docker images $(IMAGE) --format '{{.Size}}' 2>/dev/null || echo 'Not built')"
	@echo ""
	@echo "$(GREEN)Features:$(NC)"
	@echo "  ✓ FreeBSD $(VERSION)"
	@echo "  ✓ QEMU virtualization"
	@echo "  ✓ Development tools"
	@echo "  ✓ Cloud CLIs (AWS, GCP, Azure)"
	@echo "  ✓ Container tools (Docker, K8s)"
	@echo "  ✓ Programming languages"
	@echo "  ✓ AI development tools"
	@echo ""

# Hidden targets for CI/CD
.build-cache:
	@mkdir -p .build-cache

.SILENT: help info