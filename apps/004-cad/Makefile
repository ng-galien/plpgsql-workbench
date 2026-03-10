# cad — Port convention: app #4 → PG:5444 PGRST:3004 HTTP:8084
#
# Bootstrap: make up
# Teardown:  make clean

COMPOSE := docker compose
PGV_IMAGE := pg-workbench

.PHONY: up down clean logs ps sync pgv-reload mcp image

sync:
	node ../../dist/pgm/cli.js install

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

# Hot-reload modules (SQL + CSS) without wiping data
pgv-reload: sync
	@PGPASSWORD=postgres psql -h localhost -p 5444 -U postgres -f sql/02-pgv.sql -q 2>&1 && \
		echo "pgv SQL reloaded" || echo "pgv SQL reload FAILED"
	@$(COMPOSE) restart postgrest 2>/dev/null && echo "PostgREST restarted" || true
	@echo "CSS updated (browser hard-refresh needed)"

# Start MCP server for this app (auto-reload)
mcp:
	cd ../.. && WORKBENCH_MODE=dev WORKBENCH_CONFIG=apps/004-cad/workbench.json npx nodemon --watch src --ext ts --exec 'node --import tsx src/index.ts'
