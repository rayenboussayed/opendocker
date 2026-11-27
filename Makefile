DOCKER := docker
BUILD_FLAGS ?=
# BUILD_FLAGS ?= --pull --no-cache

COMPOSE_OPENCODE := -f docker-compose.opencode.yml
COMPOSE_N8N      := -f docker-compose.n8n.yml
COMPOSE_ALL      := $(COMPOSE_OPENCODE) $(COMPOSE_N8N)
COMPOSE          ?= $(COMPOSE_ALL)

# Recursive (=) so target-specific COMPOSE values are picked up
DC = $(DOCKER) compose $(COMPOSE)
UP = @trap : INT TERM; $(DC) up; $(MAKE) --no-print-directory $(1) COMPOSE="$(COMPOSE)"

.DEFAULT_GOAL := run
.PHONY: run run-clean run-opencode run-opencode-clean run-n8n run-n8n-clean build down clean

# Per-stack compose selection (also applies to prerequisites like `build`)
run-opencode run-opencode-clean: COMPOSE := $(COMPOSE_OPENCODE)
run-n8n run-n8n-clean:           COMPOSE := $(COMPOSE_N8N)

run run-opencode run-n8n:
	$(call UP,down)

run-clean run-opencode-clean run-n8n-clean: build
	$(call UP,clean)

build:
	$(DC) build $(BUILD_FLAGS)

down:
	$(DC) down --remove-orphans

clean:
	$(DC) down --rmi local --remove-orphans