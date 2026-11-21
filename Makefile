DOCKER := docker
# BUILD_FLAGS ?= --pull --no-cache
COMPOSE := -f docker-compose.opencode.yml -f docker-compose.n8n.yml
DC := $(DOCKER) compose $(COMPOSE)
UP = @trap : INT TERM; $(DC) up; $(MAKE) --no-print-directory $(1)

.DEFAULT_GOAL := run
.PHONY: run run-clean build down clean

run:
	$(call UP,down)

run-clean: build
	$(call UP,clean)

build:
	$(DC) build # $(BUILD_FLAGS)

down:
	$(DC) down --remove-orphans

clean:
	$(DC) down --rmi local --remove-orphans
