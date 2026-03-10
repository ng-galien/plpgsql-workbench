# {{NAME}} — Port convention: app #{{SLOT}} → PG:{{PG}} PGRST:{{PGRST}} HTTP:{{HTTP}}
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

# Hot-reload pgv (SQL + CSS) without wiping data
pgv-reload: sync
	@PGPASSWORD=postgres psql -h localhost -p {{PG}} -U postgres -f sql/02-pgv.sql -q 2>&1 && \
		echo "pgv SQL reloaded" || echo "pgv SQL reload FAILED"
	@$(COMPOSE) restart postgrest 2>/dev/null && echo "PostgREST restarted" || true
	@echo "CSS updated (browser hard-refresh needed)"

# Start MCP server for this app (auto-reload)
mcp:
	cd ../.. && WORKBENCH_MODE=dev WORKBENCH_CONFIG=apps/{{APP_DIR}}/workbench.json npx nodemon --watch src --ext ts --exec 'node --import tsx src/index.ts'
