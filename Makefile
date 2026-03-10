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
	PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -f modules/pgv/sql/pgv.sql -q
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
			(cd "$$app" && node ../../dist/pgm/cli.js install) || true; \
		fi; \
	done

# --- Build ---

.PHONY: build check

build:
	npm run build

check:
	npx tsc --noEmit

# --- New app scaffold ---

.PHONY: new-app

new-app:
	@test -n "$(NAME)" || (echo "Usage: make new-app NAME=myapp SLOT=4" && exit 1)
	@test -n "$(SLOT)" || (echo "Usage: make new-app NAME=myapp SLOT=4" && exit 1)
	$(eval APP_DIR := apps/$(shell printf '%03d' $(SLOT))-$(NAME))
	@test ! -d "$(APP_DIR)" || (echo "$(APP_DIR) already exists" && exit 1)
	@mkdir -p $(APP_DIR)/sql $(APP_DIR)/frontend
	@PG=$$((5440 + $(SLOT))); PGRST=$$((3000 + $(SLOT))); HTTP=$$((8080 + $(SLOT))); MCP=$$((3100 + $(SLOT))); \
	echo "Creating $(APP_DIR) (PG:$$PG PGRST:$$PGRST HTTP:$$HTTP MCP:$$MCP)"; \
	sed -e 's/{{NAME}}/$(NAME)/g' -e "s/{{SLOT}}/$(SLOT)/g" \
	    -e "s/{{PG}}/$$PG/g" -e "s/{{PGRST}}/$$PGRST/g" \
	    -e "s/{{HTTP}}/$$HTTP/g" -e "s/{{MCP}}/$$MCP/g" \
	    pgv/template/docker-compose.yml > $(APP_DIR)/docker-compose.yml; \
	APP_BASENAME=$$(basename $(APP_DIR)); \
	sed -e 's/{{NAME}}/$(NAME)/g' -e "s/{{SLOT}}/$(SLOT)/g" \
	    -e "s/{{PG}}/$$PG/g" -e "s/{{PGRST}}/$$PGRST/g" \
	    -e "s/{{HTTP}}/$$HTTP/g" -e "s/{{MCP}}/$$MCP/g" \
	    -e "s/{{APP_DIR}}/$$APP_BASENAME/g" \
	    pgv/template/Makefile > $(APP_DIR)/Makefile; \
	sed -e 's/{{NAME}}/$(NAME)/g' -e "s/{{PG}}/$$PG/g" -e "s/{{MCP}}/$$MCP/g" \
	    pgv/template/workbench.json > $(APP_DIR)/workbench.json; \
	sed -e 's/{{NAME}}/$(NAME)/g' \
	    pgv/template/01-roles.sql > $(APP_DIR)/sql/01-roles.sql; \
	sed -e "s/{{MCP}}/$$MCP/g" \
	    pgv/template/.mcp.json > $(APP_DIR)/.mcp.json; \
	mkdir -p $(APP_DIR)/.claude; \
	sed -e "s/{{MCP}}/$$MCP/g" \
	    pgv/template/.claude/settings.local.json > $(APP_DIR)/.claude/settings.local.json; \
	cp pgv/frontend/index.html $(APP_DIR)/frontend/index.html; \
	cp pgv/frontend/pgview.css $(APP_DIR)/frontend/pgview.css; \
	cp apps/001-uxlab/frontend/nginx.conf $(APP_DIR)/frontend/nginx.conf; \
	echo "Done. Next: edit $(APP_DIR)/sql/03-ddl.sql"
