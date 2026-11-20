SUDO         ?= sudo
DOCKER       = $(shell docker info >/dev/null 2>&1 && echo docker || echo $(SUDO) docker)
BUILD_FLAGS ?= --pull --no-cache
COMPOSE      = -f docker-compose.yml -f docker-compose.mcp.yml -f docker-compose.n8n.yml
# $(1) is the cleanup target to run on exit; $(2) optionally limits the services to start.
UP           = @trap : INT TERM; $(DOCKER) compose $(COMPOSE) up $(2); $(MAKE) --no-print-directory $(1)

.PHONY: run run-clean run-opencode-clean run-n8n-clean build build-opencode down clean

run:
	$(call UP,down)

run-clean: build
	$(call UP,clean)

build:
	$(DOCKER) compose $(COMPOSE) build $(BUILD_FLAGS)

build-opencode:
	$(DOCKER) compose $(COMPOSE) build $(BUILD_FLAGS) opencode

# Fresh opencode image, foreground run of that service only.
run-opencode-clean: build-opencode
	$(call UP,clean,opencode)

# Fresh opencode image plus n8n in the same foreground session; Postgres starts via depends_on.
run-n8n-clean: build-opencode
	$(call UP,clean,opencode n8n)

down:
	$(DOCKER) compose $(COMPOSE) down --remove-orphans

clean:
	$(DOCKER) compose $(COMPOSE) down --rmi local --remove-orphans

