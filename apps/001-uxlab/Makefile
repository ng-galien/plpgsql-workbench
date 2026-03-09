# uxlab — pgView component showcase
# Port convention: app #1 → PG:5441 PGRST:3001 HTTP:8081
#
# Bootstrap: make up
# Teardown:  make clean

COMPOSE := docker compose
PGV_DIR := ../../pgv

.PHONY: up down clean logs ps sync pack mcp

# Copy pgv framework files from canonical source
sync:
	cp $(PGV_DIR)/sql/00-extensions.sql sql/00-extensions.sql
	cp $(PGV_DIR)/sql/pgv.sql sql/02-pgv.sql
	cp $(PGV_DIR)/frontend/pgview.css frontend/pgview.css

# Start all services (postgres + postgrest + nginx)
up: sync
	$(COMPOSE) up -d
	@echo ""
	@echo "  postgres  → localhost:5441"
	@echo "  postgrest → localhost:3001"
	@echo "  frontend  → http://localhost:8081"

# Stop services (data persists)
down:
	$(COMPOSE) down

# Stop + wipe data (triggers fresh initdb on next up)
clean:
	$(COMPOSE) down -v

# View logs
logs:
	$(COMPOSE) logs -f

# Service status
ps:
	$(COMPOSE) ps

# Start MCP server for this app (auto-reload)
mcp:
	cd ../.. && WORKBENCH_MODE=dev WORKBENCH_CONFIG=apps/001-uxlab/workbench.json npx nodemon --watch src --ext ts --exec 'node --import tsx src/index.ts'

# Re-export functions from dev DB into init SQL files
# Run this after iterating with pg_func_set on dev DB (port 5433)
pack:
	@echo "Connect to dev DB and run:"
	@echo "  pg_pack schemas:pgv,pgv_ut path:pgv/sql/pgv.sql"
	@echo "  pg_pack schemas:uxlab path:apps/uxlab/sql/04-functions.sql"
	@echo "Then: make clean && make up"
