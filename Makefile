# plpgsql-workbench — Platform Makefile
#
# Dev DB:     make dev-up / make dev-down / make dev-clean
# Apps:       make app-up APP=uxlab / make app-down APP=docman
# MCP:        npm run dev          (all packs, dev DB)
#             npm run dev:docman   (docman packs, docman DB)

PGV_IMAGE := pg-workbench

# --- Docker image (postgres + plpgsql_check + pgtap) ---

.PHONY: image

image:
	@docker image inspect $(PGV_IMAGE) > /dev/null 2>&1 || \
		(echo "Building $(PGV_IMAGE)..." && docker build -t $(PGV_IMAGE) docker/)

# --- Dev DB (port 5433) ---

.PHONY: dev-up dev-down dev-clean dev-init

dev-up: image
	docker compose up -d
	@echo ""
	@echo "  Dev DB → localhost:5433"

dev-down:
	docker compose down

dev-clean:
	docker compose down -v

# Load pgv framework into dev DB (after fresh start)
dev-init: dev-up
	@echo "Waiting for DB..."
	@sleep 2
	PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -f modules/pgv/sql/functions.sql -q
	@echo "pgv loaded into dev DB"

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

.PHONY: sync-pgv sync-modules

sync-pgv: sync-modules

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

# --- New app scaffold ---
# Use: pgm init (from the target app directory)
# See: docs/PGM.md
