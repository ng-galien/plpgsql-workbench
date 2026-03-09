# {{NAME}} — Port convention: app #{{SLOT}} → PG:{{PG}} PGRST:{{PGRST}} HTTP:{{HTTP}}
#
# Bootstrap: make up
# Teardown:  make clean

COMPOSE := docker compose
PGV_DIR := ../../pgv
PGV_IMAGE := pg-workbench

.PHONY: up down clean logs ps sync mcp image

sync:
	cp $(PGV_DIR)/sql/00-extensions.sql sql/00-extensions.sql
	cp $(PGV_DIR)/sql/pgv.sql sql/02-pgv.sql
	cp $(PGV_DIR)/frontend/pgview.css frontend/pgview.css

# Build pg-workbench image if missing
image:
	@docker image inspect $(PGV_IMAGE) > /dev/null 2>&1 || \
		(echo "Building $(PGV_IMAGE)..." && docker build -t $(PGV_IMAGE) ../../docker/)

up: image sync
	$(COMPOSE) up -d
	@echo ""
	@echo "  postgres  → localhost:{{PG}}"
	@echo "  postgrest → localhost:{{PGRST}}"
	@echo "  frontend  → http://localhost:{{HTTP}}"

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down -v

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

# Start MCP server for this app (auto-reload)
mcp:
	cd ../.. && WORKBENCH_MODE=dev WORKBENCH_CONFIG=apps/{{SLOT}}-{{NAME}}/workbench.json npx nodemon --watch src --ext ts --exec 'node --import tsx src/index.ts'
