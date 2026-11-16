DOCKER       = $(shell docker info >/dev/null 2>&1 && echo docker || echo $(SUDO) docker)
BUILD_FLAGS ?= --pull --no-cache
UP           = @trap : INT TERM; $(DOCKER) compose up; $(MAKE) --no-print-directory $(1)

.PHONY: run run-clean build down clean docker test

run:
	$(call UP,down)

run-clean: build
	$(call UP,clean)

build:
	$(DOCKER) compose build $(BUILD_FLAGS)

down:
	$(DOCKER) compose down --remove-orphans

clean:
	$(DOCKER) compose down --rmi local --remove-orphans

