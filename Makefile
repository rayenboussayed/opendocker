SUDO ?= sudo
DOCKER := $(shell docker info >/dev/null 2>&1 && echo docker || echo $(SUDO) docker)
BUILD_FLAGS ?= --pull --no-cache
COMPOSE := -f docker-compose.yml -f docker-compose.mcp.yml -f docker-compose.n8n.yml
DC := $(DOCKER) compose $(COMPOSE)
OPENCODE_SERVICES := opencode mcp-gateway
N8N_SERVICES := $(OPENCODE_SERVICES) n8n searxng
UP = @trap : INT TERM; $(DC) up $(2); $(MAKE) --no-print-directory $(1)

.DEFAULT_GOAL := run
.PHONY: run run-clean run-opencode-clean run-n8n-clean build down clean

run:
	$(call UP,down)

run-clean: build
	$(call UP,clean)

run-opencode-clean: build
	$(call UP,clean,$(OPENCODE_SERVICES))

run-n8n-clean: build
	$(call UP,clean,$(N8N_SERVICES))

build:
	$(DC) build $(BUILD_FLAGS)

down:
	$(DC) down --remove-orphans

clean:
	$(DC) down --rmi local --remove-orphans
