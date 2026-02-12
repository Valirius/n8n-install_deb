.PHONY: help install update update-preview git-pull clean clean-all logs status monitor restart stop start show-restarts doctor switch-beta switch-stable import setup-tls

PROJECT_NAME := localai

# Include n8n-workers compose if it exists (generated during install)
COMPOSE_FILES := -f docker-compose.yml
ifneq ($(wildcard docker-compose.n8n-workers.yml),)
COMPOSE_FILES += -f docker-compose.n8n-workers.yml
endif
# Include n8n-import override when profile is active (adds depends_on so n8n waits for import)
ifneq ($(shell grep -E '^COMPOSE_PROFILES=' .env 2>/dev/null | cut -d= -f2- | tr ',' '\n' | grep -x 'n8n-import' | head -1),)
COMPOSE_FILES += -f docker-compose.n8n-import.yml
endif

help:
	@echo "n8n-install - Available commands:"
	@echo ""
	@echo "  make install           Full installation"
	@echo "  make update            Update system and services (resets to origin)"
	@echo "  make update-preview    Preview available updates (dry-run)"
	@echo "  make git-pull          Update for forks (merges from upstream)"
	@echo "  make clean             Remove unused Docker resources (preserves data)"
	@echo "  make clean-all         Remove ALL Docker resources including data (DANGEROUS)"
	@echo ""
	@echo "  make logs              View logs (all services)"
	@echo "  make logs s=<service>  View logs for specific service"
	@echo "  make status            Show container status"
	@echo "  make monitor           Live CPU/memory monitoring"
	@echo "  make restart           Restart all services"
	@echo "  make stop              Stop all services"
	@echo "  make start             Start all services"
	@echo "  make show-restarts     Show restart count per container"
	@echo "  make doctor            Run system diagnostics"
	@echo "  make import            Import n8n workflows from backup (one-shot)"
	@echo "  make import n=10       Import first N workflows only"
	@echo "  (n8n-import profile: add to COMPOSE_PROFILES for import at startup)"
	@echo "  make setup-tls         Configure custom TLS certificates"
	@echo ""
	@echo "  make switch-beta       Switch to beta (develop branch)"
	@echo "  make switch-stable     Switch to stable (main branch)"

install:
	sudo bash ./scripts/install.sh

update:
	sudo bash ./scripts/update.sh

update-preview:
	bash ./scripts/update_preview.sh

git-pull:
	sudo GIT_MODE=merge bash ./scripts/update.sh

clean:
	sudo bash ./scripts/docker_cleanup.sh

clean-all:
	@echo "WARNING: This will delete ALL Docker resources including application data!"
	@echo "Press Ctrl+C to cancel, or wait 10 seconds to continue..."
	@sleep 10
	docker system prune -a --volumes -f

logs:
ifdef s
	docker compose -p $(PROJECT_NAME) $(COMPOSE_FILES) logs -f --tail=200 $(s)
else
	docker compose -p $(PROJECT_NAME) $(COMPOSE_FILES) logs -f --tail=100
endif

status:
	docker compose -p $(PROJECT_NAME) $(COMPOSE_FILES) ps

monitor:
	docker stats

restart:
	bash ./scripts/restart.sh

stop:
	docker compose -p $(PROJECT_NAME) $(COMPOSE_FILES) stop

start:
	docker compose -p $(PROJECT_NAME) $(COMPOSE_FILES) start

show-restarts:
	@docker ps -q | while read id; do \
		name=$$(docker inspect --format '{{.Name}}' $$id | sed 's/^\/\(.*\)/\1/'); \
		restarts=$$(docker inspect --format '{{.RestartCount}}' $$id); \
		echo "$$name restarted $$restarts times"; \
	done

doctor:
	bash ./scripts/doctor.sh

switch-beta:
	git restore docker-compose.yml
	git checkout develop
	sudo bash ./scripts/update.sh

switch-stable:
	git restore docker-compose.yml
	git checkout main
	sudo bash ./scripts/update.sh

import:
ifdef n
	docker compose -p $(PROJECT_NAME) $(COMPOSE_FILES) run --rm -e FORCE_IMPORT=true -e IMPORT_LIMIT=$(n) n8n-import
else
	docker compose -p $(PROJECT_NAME) $(COMPOSE_FILES) run --rm -e FORCE_IMPORT=true n8n-import
endif

setup-tls:
	bash ./scripts/setup_custom_tls.sh
