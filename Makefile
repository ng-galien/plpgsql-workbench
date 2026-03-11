# plpgsql-workbench — Platform Makefile
#
# Dev stack:  make dev-up / make dev-down / make dev-clean
# Apps:       make app-up APP=uxlab / make app-down APP=docman
# MCP:        npm run dev          (all packs, dev DB)

PGV_IMAGE := pg-workbench

# --- Docker image (postgres + postgis + plpgsql_check + pgtap) ---

.PHONY: image

image:
	@docker image inspect $(PGV_IMAGE) > /dev/null 2>&1 || \
		(echo "Building $(PGV_IMAGE)..." && docker build -t $(PGV_IMAGE) docker/)

# --- Dev stack (postgres:5433 + postgrest:3000 + nginx:8080) ---

.PHONY: dev-up dev-down dev-clean dev-init dev-sync

dev-up: image dev-env
	docker compose up -d
	@echo ""
	@echo "  postgres  → localhost:5433"
	@echo "  postgrest → localhost:3000  (schemas: $$(cat .env 2>/dev/null | grep PGRST_DB_SCHEMAS | cut -d= -f2))"
	@echo "  frontend  → http://localhost:8080"

# Generate .env with PGRST_DB_SCHEMAS from modules/*/module.json (includes _ut, _qa)
dev-env:
	@schemas=$$(python3 -c "import json,glob; \
		s=[]; \
		[s.extend([p, p+'_ut', p+'_qa']) for f in sorted(glob.glob('modules/*/module.json')) \
		 for p in [json.load(open(f)).get('schemas',{}).get('public','')] if p]; \
		s.sort(key=lambda x: (0 if x.startswith('pgv') else 1, x)); \
		print(','.join(s))" 2>/dev/null || echo "pgv"); \
	echo "PGRST_DB_SCHEMAS=$$schemas" > .env

dev-down:
	docker compose down

dev-clean:
	docker compose down
	@rm -rf dev/frontend/*
	@echo "Data preserved in data/pgdata/ — delete manually if needed"

# Sync module frontend assets into dev/frontend/ for nginx
dev-sync:
	@echo "Syncing module assets → dev/frontend/"
	@mkdir -p dev/frontend
	@for mod in modules/*/; do \
		if [ -d "$$mod/frontend" ]; then \
			cp -r "$$mod/frontend/"* dev/frontend/ 2>/dev/null || true; \
		fi; \
	done
	@echo "Generating dev index..."
	@python3 -c "\
	import json, glob; \
	mods = []; \
	[mods.append({'schema': m.get('schemas',{}).get('qa',''), 'name': m.get('name','?'), 'desc': m.get('description','')}) \
	 for f in sorted(glob.glob('modules/*/module.json')) \
	 for m in [json.load(open(f))] \
	 if m.get('schemas',{}).get('qa')]; \
	links = ''.join('<li><a href=\"/%s/\">%s</a><br><small>%s</small></li>' % (m['schema'], m['name'], m['desc']) for m in mods); \
	print('<!DOCTYPE html><html lang=fr data-theme=light><head><meta charset=utf-8><meta name=viewport content=\"width=device-width,initial-scale=1\"><title>Dev — Modules</title><link rel=stylesheet href=https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css><link rel=stylesheet href=/pgview.css></head><body><main class=container><hgroup><h2>Dev — Modules</h2><p>Choisir un module pour voir sa QA</p></hgroup><ul>%s</ul></main></body></html>' % links)" \
	> dev/frontend/dev-index.html
	@echo "Done"

# Deploy all modules to dev DB (after fresh start)
dev-init: dev-up dev-sync
	@echo "Waiting for DB..."
	@sleep 2
	@for mod in modules/*/; do \
		for sql in "$$mod"build/*.sql; do \
			[ -f "$$sql" ] && echo "  Loading $$sql" && \
			PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -f "$$sql" -q 2>&1 | grep -v "^$$" || true; \
		done; \
	done
	@echo "Creating QA schemas..."
	@for mod in modules/*/; do \
		schema=$$(python3 -c "import json; print(json.load(open('$${mod}module.json')).get('schemas',{}).get('qa',''))" 2>/dev/null); \
		if [ -n "$$schema" ]; then \
			echo "  CREATE SCHEMA $$schema"; \
			PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -c \
				"CREATE SCHEMA IF NOT EXISTS $$schema; GRANT USAGE ON SCHEMA $$schema TO web_anon; GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA $$schema TO web_anon;" -q 2>&1 | grep -v "^$$" || true; \
		fi; \
	done
	@echo "Loading QA seeds..."
	@for mod in modules/*/; do \
		if [ -f "$${mod}qa/seed.sql" ]; then \
			echo "  Loading $${mod}qa/seed.sql" && \
			PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -f "$${mod}qa/seed.sql" -q 2>&1 | grep -v "^$$" || true; \
		fi; \
	done
	@echo "All modules loaded into dev DB"

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

.PHONY: sync-modules

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

# --- Scaffold ---
# App:    pgm app init (from target directory)
# Module: pgm module new <name> [--port <mcp_port>]
# See:    docs/PGM.md
