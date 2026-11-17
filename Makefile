SUDO         ?= sudo
DOCKER       = $(shell docker info >/dev/null 2>&1 && echo docker || echo $(SUDO) docker)
BUILD_FLAGS ?= --pull --no-cache
COMPOSE      = -f docker-compose.yml -f docker-compose.mcp.yml
UP           = @trap : INT TERM; $(DOCKER) compose $(COMPOSE) up; $(MAKE) --no-print-directory $(1)

.PHONY: run run-clean build down clean secrets docker test

run: secrets
	$(call UP,down)

run-clean: secrets build
	$(call UP,clean)

secrets:
	@./prepare-mcp-secrets.sh

build:
	$(DOCKER) compose $(COMPOSE) build $(BUILD_FLAGS)

down:
	$(DOCKER) compose $(COMPOSE) down --remove-orphans

clean:
	$(DOCKER) compose $(COMPOSE) down --rmi local --remove-orphans

