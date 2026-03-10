# plpgsql-workbench — Platform Makefile
#
# Dev stack:  make dev-up / make dev-down / make dev-clean
# Apps:       make app-up APP=uxlab / make app-down APP=docman
# MCP:        npm run dev          (all packs, dev DB)

PGV_IMAGE := pg-workbench

# --- Docker image (postgres + postgis + plpgsql_check + pgtap) ---

.PHONY: image

image:
	@docker image inspect $(PGV_IMAGE) > /dev/null 2>&1 || \
		(echo "Building $(PGV_IMAGE)..." && docker build -t $(PGV_IMAGE) docker/)

# --- Dev stack (postgres:5433 + postgrest:3000 + nginx:8080) ---

.PHONY: dev-up dev-down dev-clean dev-init dev-sync

dev-up: image
	docker compose up -d
	@echo ""
	@echo "  postgres  → localhost:5433"
	@echo "  postgrest → localhost:3000"
	@echo "  frontend  → http://localhost:8080"

dev-down:
	docker compose down

dev-clean:
	docker compose down -v
	@rm -rf dev/frontend/*

# Sync module frontend assets into dev/frontend/ for nginx
dev-sync:
	@echo "Syncing module assets → dev/frontend/"
	@mkdir -p dev/frontend
	@for mod in modules/*/; do \
		if [ -d "$$mod/frontend" ]; then \
			cp -r "$$mod/frontend/"* dev/frontend/ 2>/dev/null || true; \
		fi; \
	done
	@echo "Done"

# Deploy all modules to dev DB (after fresh start)
dev-init: dev-up dev-sync
	@echo "Waiting for DB..."
	@sleep 2
	@for mod in modules/*/; do \
		for sql in "$$mod"sql/*.sql; do \
			[ -f "$$sql" ] && echo "  Loading $$sql" && \
			PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -f "$$sql" -q 2>&1 | grep -v "^$$" || true; \
		done; \
	done
	@echo "All modules loaded into dev DB"

# --- App management ---

.PHONY: app-up app-down app-clean app-logs

app-up:
	@test -n "$(APP)" || (echo "Usage: make app-up APP=uxlab" && exit 1)
	$(MAKE) -C apps/$(APP) up

app-down:
	@test -n "$(APP)" || (echo "Usage: make app-down APP=uxlab" && exit 1)
	$(MAKE) -C apps/$(APP) down

app-clean:
	@test -n "$(APP)" || (echo "Usage: make app-clean APP=uxlab" && exit 1)
	$(MAKE) -C apps/$(APP) clean

app-logs:
	@test -n "$(APP)" || (echo "Usage: make app-logs APP=uxlab" && exit 1)
	$(MAKE) -C apps/$(APP) logs

# --- Sync modules to all apps ---

.PHONY: sync-modules

sync-modules:
	@for app in apps/*/; do \
		if [ -f "$$app/workbench.json" ]; then \
			echo "Syncing modules → $$app"; \
			(cd "$$app" && node ../../dist/pgm/cli.js app install) || true; \
		fi; \
	done

# --- Build ---

.PHONY: build check

build:
	npm run build

check:
	npx tsc --noEmit

# --- Scaffold ---
# App:    pgm app init (from target directory)
# Module: pgm module new <name> [--port <mcp_port>]
# See:    docs/PGM.md
