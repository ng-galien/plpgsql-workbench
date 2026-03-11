# 004-cad — PG:5444 PGRST:3004 HTTP:8084
COMPOSE := docker compose

.PHONY: up down init clean logs ps sync deploy reload mcp image

image:
	@docker image inspect pg-workbench > /dev/null 2>&1 || \
		(echo "Building pg-workbench..." && docker build -t pg-workbench ../../docker/)

sync:
	node ../../dist/pgm/cli.js app install

up: image sync
	$(COMPOSE) up -d
	@echo ""
	@echo "  postgres  → localhost:5444"
	@echo "  postgrest → localhost:3004  (schemas: $$(grep PGRST_DB_SCHEMAS .env 2>/dev/null | cut -d= -f2))"
	@echo "  frontend  → http://localhost:8084"

init: clean up
	@echo "Fresh start complete"

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down -v

deploy:
	node ../../dist/pgm/cli.js app deploy --apply

reload: sync
	@PGPASSWORD=postgres psql -h localhost -p 5444 -U postgres \
		-c "SELECT pg_notify('pgrst', 'reload schema')" -q 2>&1 && \
		echo "PostgREST schema cache reloaded" || true

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

mcp:
	cd ../.. && WORKBENCH_MODE=dev WORKBENCH_CONFIG=apps/004-cad/workbench.json npx nodemon --watch src --ext ts --exec 'node --import tsx src/index.ts'
