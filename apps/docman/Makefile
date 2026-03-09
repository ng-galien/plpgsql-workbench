# docman — Document classification system
# Port convention: app #3 → PG:5443 PGRST:3003 HTTP:8083
#
# Bootstrap: make up
# Teardown:  make clean

COMPOSE := docker compose
PGV_DIR := ../../pgv

.PHONY: up down clean logs ps sync pack

# Copy pgv framework files from canonical source
sync:
	cp $(PGV_DIR)/sql/pgv.sql sql/02-pgv.sql

# Start all services (postgres + postgrest + nginx)
up: sync
	$(COMPOSE) up -d
	@echo ""
	@echo "  postgres  → localhost:5443"
	@echo "  postgrest → localhost:3003"
	@echo "  frontend  → http://localhost:8083"

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

# Re-export functions from dev DB into init SQL files
pack:
	@echo "Connect to dev DB and run:"
	@echo "  pg_pack schemas:pgv,pgv_ut path:pgv/sql/pgv.sql"
	@echo "  pg_pack schemas:docman,docman_ut path:apps/docman/sql/04-functions.sql"
	@echo "Then: make clean && make up"
