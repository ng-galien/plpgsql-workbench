# cad — Port convention: app #4 → PG:5444 PGRST:3004 HTTP:8084
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
	@echo "  postgres  → localhost:5444"
	@echo "  postgrest → localhost:3004"
	@echo "  frontend  → http://localhost:8084"

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
	cd ../.. && WORKBENCH_MODE=dev WORKBENCH_CONFIG=apps/004-cad/workbench.json npx nodemon --watch src --ext ts --exec 'node --import tsx src/index.ts'
