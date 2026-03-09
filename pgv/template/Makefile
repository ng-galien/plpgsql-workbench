# {{NAME}} — Port convention: app #{{SLOT}} → PG:{{PG}} PGRST:{{PGRST}} HTTP:{{HTTP}}
#
# Bootstrap: make up
# Teardown:  make clean

COMPOSE := docker compose
PGV_DIR := ../../pgv

.PHONY: up down clean logs ps sync mcp

sync:
	cp $(PGV_DIR)/sql/pgv.sql sql/02-pgv.sql
	cp $(PGV_DIR)/frontend/pgview.css frontend/pgview.css

up: sync
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
