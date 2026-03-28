# plpgsql-workbench — Platform Makefile
#
# Quick start:
#   make dev-up        Start dev stack (postgres + postgrest)
#   npm run dev        Start MCP server (port 3100, separate terminal)
#   cd app && npm run dev  Start React frontend (port 5173)
#   make dev-init      First time: load all modules into DB
#
# Daily:
#   make dev-down      Stop stack (data preserved)
#   make dev-clean     Stop stack (data preserved)
#
# Apps:
#   make app-up APP=uxlab    Start an app stack
#   make app-down APP=uxlab  Stop an app stack

PGV_IMAGE := pg-workbench

# --- Docker image (postgres + postgis + plpgsql_check + pgtap) ---

.PHONY: image

image: ## Build pg-workbench Docker image (if not exists)
	@docker image inspect $(PGV_IMAGE) > /dev/null 2>&1 || \
		(echo "Building $(PGV_IMAGE)..." && docker build -t $(PGV_IMAGE) docker/)

# --- Dev stack (postgres:5433 + postgrest:3000) ---

.PHONY: dev-up dev-down dev-clean dev-init

dev-up: image dev-env ## Start dev stack: postgres:5433, postgrest:3000
	docker compose up -d
	@echo ""
	@echo "  postgres  → localhost:5433"
	@echo "  postgrest → localhost:3000  (schemas: $$(cat .env 2>/dev/null | grep PGRST_DB_SCHEMAS | cut -d= -f2))"
	@echo "  frontend  → cd app && npm run dev (port 5173)"

dev-env: # (internal) Generate .env with PGRST_DB_SCHEMAS from module.json files
	@schemas=$$(python3 -c "import json,glob; \
		s=[]; \
		[s.extend([p, p+'_ut', p+'_qa']) for f in sorted(glob.glob('modules/*/module.json')) \
		 for p in [json.load(open(f)).get('schemas',{}).get('public','')] if p]; \
		s.sort(key=lambda x: (0 if x.startswith('pgv') else 1, x)); \
		print(','.join(s))" 2>/dev/null || echo "pgv"); \
	echo "PGRST_DB_SCHEMAS=$$schemas" > .env

dev-down: ## Stop dev stack (data preserved in data/pgdata/)
	docker compose down

dev-clean: ## Stop stack (data preserved)
	docker compose down
	@echo "Data preserved in data/pgdata/ — delete manually if needed"

dev-init: dev-up ## First start: load all build/*.sql into dev DB
	@echo "Waiting for DB..."
	@sleep 2
	@for mod in modules/*/; do \
		for sql in "$$mod"build/*.sql; do \
			[ -f "$$sql" ] && echo "  Loading $$sql" && \
			PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -f "$$sql" -q 2>&1 | grep -v "^$$" || true; \
		done; \
	done
	@echo "Running i18n seeds..."
	@for mod in modules/*/; do \
		schema=$$(python3 -c "import json; print(json.load(open('$${mod}module.json')).get('schemas',{}).get('public',''))" 2>/dev/null); \
		if [ -n "$$schema" ]; then \
			has_i18n=$$(PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -tAc \
				"SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = '$$schema' AND p.proname = 'i18n_seed'" 2>/dev/null); \
			if [ "$$has_i18n" = "1" ]; then \
				PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -c "SELECT $$schema.i18n_seed()" -q 2>&1 | grep -v "^$$" || true; \
				echo "  i18n $$schema"; \
			fi; \
		fi; \
	done
	@echo "Granting QA schema permissions..."
	@for mod in modules/*/; do \
		schema=$$(python3 -c "import json; print(json.load(open('$${mod}module.json')).get('schemas',{}).get('qa',''))" 2>/dev/null); \
		if [ -n "$$schema" ]; then \
			PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -c \
				"GRANT USAGE ON SCHEMA $$schema TO anon; GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA $$schema TO anon; GRANT SELECT ON ALL TABLES IN SCHEMA $$schema TO anon;" -q 2>&1 | grep -v "^$$" || true; \
		fi; \
	done
	@echo "Seeding QA data..."
	@for mod in modules/*/; do \
		schema=$$(python3 -c "import json; print(json.load(open('$${mod}module.json')).get('schemas',{}).get('qa',''))" 2>/dev/null); \
		if [ -n "$$schema" ]; then \
			has_seed=$$(PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -tAc \
				"SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = '$$schema' AND p.proname = 'seed'" 2>/dev/null); \
			if [ "$$has_seed" = "1" ]; then \
				echo "  $$schema.seed()"; \
				PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -c \
					"SET app.tenant_id = 'dev'; SELECT $$schema.seed();" -q 2>&1 | grep -v "^$$" || true; \
			fi; \
		fi; \
	done
	@echo "All modules loaded into dev DB"

i18n-sync: ## Re-run all i18n_seed() functions (refresh translations)
	@for mod in modules/*/; do \
		schema=$$(python3 -c "import json; print(json.load(open('$${mod}module.json')).get('schemas',{}).get('public',''))" 2>/dev/null); \
		if [ -n "$$schema" ]; then \
			has_i18n=$$(PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -tAc \
				"SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = '$$schema' AND p.proname = 'i18n_seed'" 2>/dev/null); \
			if [ "$$has_i18n" = "1" ]; then \
				PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -c "SELECT $$schema.i18n_seed()" -q 2>&1 | grep -v "^$$" || true; \
				echo "  i18n $$schema"; \
			fi; \
		fi; \
	done
	@echo "i18n sync complete"

# --- App management (make app-up APP=name) ---

.PHONY: app-up app-down app-clean app-logs

app-up: ## Start app stack (APP=name required)
	@test -n "$(APP)" || (echo "Usage: make app-up APP=uxlab" && exit 1)
	$(MAKE) -C apps/$(APP) up

app-down: ## Stop app stack
	@test -n "$(APP)" || (echo "Usage: make app-down APP=uxlab" && exit 1)
	$(MAKE) -C apps/$(APP) down

app-clean: ## Stop + clean app stack
	@test -n "$(APP)" || (echo "Usage: make app-clean APP=uxlab" && exit 1)
	$(MAKE) -C apps/$(APP) clean

app-logs: ## Tail app logs
	@test -n "$(APP)" || (echo "Usage: make app-logs APP=uxlab" && exit 1)
	$(MAKE) -C apps/$(APP) logs

# --- Sync modules to all apps ---

.PHONY: sync-modules

sync-modules: ## Run pgm install in every app
	@for app in apps/*/; do \
		if [ -f "$$app/workbench.json" ]; then \
			echo "Syncing modules → $$app"; \
			(cd "$$app" && node ../../dist/pgm/cli.js app install) || true; \
		fi; \
	done

# --- Docker agents (containerized Claude Code with channel) ---

agent-docker: ## Start one containerized agent (M=name). Ex: make agent-docker M=docs
	@test -n "$(M)" || (echo "Usage: make agent-docker M=docs" && exit 1)
	cd docker/agent && docker compose up agent-$(M)

agents-docker: ## Start all containerized agents
	cd docker/agent && docker compose up -d

agents-docker-down: ## Stop all containerized agents
	cd docker/agent && docker compose down

# --- Team (one tmux session per module, with channel) ---

STRIP_VARS := CLAUDECODE CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_SESSION_ID \
	CLAUDE_CODE_CONVERSATION_ID CLAUDE_CODE_TASK_ID \
	NON_INTERACTIVE MCP_TRANSPORT MCP_SESSION_ID
CHANNEL_FLAG := --dangerously-load-development-channels server:workbench-msg

.PHONY: team team-stop team-restart team-status team-ping team-confirm member member-stop member-ping member-log

team: ## Start all team members (one tmux session per module)
	@for mod in modules/*/; do \
		name=$$(basename "$$mod"); \
		if tmux has-session -t "$$name" 2>/dev/null; then \
			echo "  OK    $$name (already running)"; \
		else \
			printf '#!/bin/sh\nunset $(STRIP_VARS)\nclaude $(CHANNEL_FLAG) -c 2>/dev/null || exec claude $(CHANNEL_FLAG)\n' > "/tmp/pgw-spawn-$$name.sh"; \
			chmod 700 "/tmp/pgw-spawn-$$name.sh"; \
			tmux new-session -d -s "$$name" -c "$$mod" "/tmp/pgw-spawn-$$name.sh"; \
			tmux set-option -t "$$name" history-limit 50000 2>/dev/null || true; \
			tmux set-option -t "$$name" remain-on-exit on 2>/dev/null || true; \
			echo "  JOIN  $$name"; \
		fi; \
	done

team-confirm: ## Send Enter to all members (accept channel confirmation)
	@for mod in modules/*/; do \
		name=$$(basename "$$mod"); \
		tmux send-keys -t "$$name" Enter 2>/dev/null && echo "  ENTER $$name"; \
	done

team-stop: ## Stop all team members
	@for mod in modules/*/; do \
		name=$$(basename "$$mod"); \
		if tmux has-session -t "$$name" 2>/dev/null; then \
			tmux kill-session -t "$$name"; \
			rm -f "/tmp/pgw-tmux-$$name.log" "/tmp/pgw-spawn-$$name.sh"; \
			echo "  LEAVE $$name"; \
		fi; \
	done

team-restart: team-stop ## Restart all team members
	@echo "  Waiting 3s for cleanup..."
	@sleep 3
	@$(MAKE) team

team-status: ## Show current activity of each team member
	@for mod in modules/*/; do \
		name=$$(basename "$$mod"); \
		if tmux has-session -t "$$name" 2>/dev/null; then \
			pane=$$(tmux capture-pane -t "$$name" -p 2>/dev/null); \
			activity=$$(echo "$$pane" | grep -E '(Brewing|Cascading|Crunching|Churning|Cooking|Embellishing|Manifesting|Sautéed|Thinking|Worked|Cooked|Crunched|thinking|pg_func_set|pg_pack|pg_schema|pg_test|pg_query|pg_msg|Write|Edit|Read)' | tail -1); \
			if [ -n "$$activity" ]; then \
				printf "  \033[1;33m⚡ %-12s\033[0m %s\n" "$$name" "$$activity"; \
			else \
				printf "  \033[2m·  %-12s\033[0m idle\n" "$$name"; \
			fi; \
		fi; \
	done

team-ping: ## Send "go" to all team members
	@for mod in modules/*/; do \
		name=$$(basename "$$mod"); \
		if tmux has-session -t "$$name" 2>/dev/null; then \
			tmux send-keys -t "$$name" "go" Enter; \
			echo "  PING  $$name"; \
		fi; \
	done

# --- Single member (make member M=crm, make member-stop M=crm) ---

member: ## Start one team member (M=name). Ex: make member M=docs
	@test -n "$(M)" || (echo "Usage: make member M=docs" && exit 1)
	@if tmux has-session -t "$(M)" 2>/dev/null; then \
		echo "  OK    $(M) (already running)"; \
	else \
		printf '#!/bin/sh\nunset $(STRIP_VARS)\nclaude $(CHANNEL_FLAG) -c 2>/dev/null || exec claude $(CHANNEL_FLAG)\n' > "/tmp/pgw-spawn-$(M).sh"; \
		chmod 700 "/tmp/pgw-spawn-$(M).sh"; \
		tmux new-session -d -s "$(M)" -c "modules/$(M)" "/tmp/pgw-spawn-$(M).sh"; \
		tmux set-option -t "$(M)" history-limit 50000 2>/dev/null || true; \
		tmux set-option -t "$(M)" remain-on-exit on 2>/dev/null || true; \
		echo "  JOIN  $(M)"; \
	fi

member-stop: ## Stop one team member (M=name). Ex: make member-stop M=crm
	@test -n "$(M)" || (echo "Usage: make member-stop M=crm" && exit 1)
	@if tmux has-session -t "$(M)" 2>/dev/null; then \
		tmux kill-session -t "$(M)"; \
		rm -f "/tmp/pgw-tmux-$(M).log" "/tmp/pgw-spawn-$(M).sh"; \
		echo "  LEAVE $(M)"; \
	else \
		echo "  $(M) not running"; \
	fi

member-restart: member-stop member ## Restart one team member (M=name)

member-ping: ## Send "go" to one team member (M=name). Ex: make member-ping M=docs
	@test -n "$(M)" || (echo "Usage: make member-ping M=docs" && exit 1)
	@if tmux has-session -t "$(M)" 2>/dev/null; then \
		tmux send-keys -t "$(M)" "go" Enter; \
		echo "  PING  $(M)"; \
	else \
		echo "  $(M) not running"; \
	fi

member-log: ## Show last 50 lines from team member (M=name). Ex: make member-log M=crm
	@test -n "$(M)" || (echo "Usage: make member-log M=crm" && exit 1)
	@if tmux has-session -t "$(M)" 2>/dev/null; then \
		tmux capture-pane -t "$(M)" -p -S -50; \
	else \
		echo "  $(M) not running"; \
	fi

agent-attach: ## Attach to agent tmux session (M=name). Ex: make agent-attach M=crm
	@test -n "$(M)" || (echo "Usage: make agent-attach M=crm" && exit 1)
	tmux attach-session -t "$(M)"

# --- Build ---

.PHONY: build check help

build: ## Compile TypeScript (tsc → dist/)
	npm run build

ESBUILD_SHELL = npx esbuild cloudflare/pages/src/pgview.ts \
	--bundle --outfile=cloudflare/pages/pgview.js \
	--format=iife --global-name=pgv \
	--target=es2022,chrome90,firefox90,safari15 \
	--external:alpine --external:marked --external:panzoom --external:d3

build-shell: ## Bundle pgView shell kernel (esbuild → cloudflare/pages/pgview.js)
	@$(ESBUILD_SHELL) --minify
	@echo "  pgview.js → cloudflare/pages/"

watch-shell: ## Live reload pgView shell (esbuild watch)
	$(ESBUILD_SHELL) --watch --sourcemap

ESBUILD_ILL = npx esbuild modules/document/frontend/illustrator/app.ts \
	--bundle --format=esm --external:d3 --loader:.css=css \
	--target=es2022,chrome90,firefox90,safari15

build-illustrator: ## Bundle illustrator client (esbuild → dist/ + cloudflare/pages/)
	@$(ESBUILD_ILL) --outfile=modules/document/frontend/illustrator/dist/app.js --minify
	@cp modules/document/frontend/illustrator/dist/app.js modules/document/frontend/illustrator/dist/app.css cloudflare/pages/illustrator/
	@echo "  app.js + app.css → dist/ + cloudflare/pages/illustrator/"

watch-illustrator: ## Live reload illustrator client (esbuild watch → cloudflare/pages + dist/)
	$(ESBUILD_ILL) --outdir=cloudflare/pages/illustrator --watch --sourcemap

check: check-server check-shell check-lint check-css build-shell build-illustrator ## Full quality gate
	@echo "✓ All checks passed"

check-server: ## Type-check MCP server (src/)
	@echo "  tsc server ..."
	@npx tsc --noEmit

check-shell: ## Type-check pgView shell (strict + unused)
	@echo "  tsc shell ..."
	@npx tsc --noEmit -p cloudflare/pages/tsconfig.json

check-lint: ## Biome lint (TS)
	@echo "  biome lint ..."
	@npx biome lint

check-css: ## Stylelint (CSS)
	@echo "  stylelint ..."
	@npx stylelint "cloudflare/pages/src/css/*.css"

# --- Help ---

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | \
		awk -F ':.*## ' '{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

# --- Export ---

.PHONY: export-svg

export-svg: ## Export all canvas SVGs to tmp/
	@mkdir -p tmp
	@PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -d postgres -t -A -c \
		"SELECT c.id || '|' || c.name FROM document.canvas c" | \
	while IFS='|' read -r id name; do \
		safe=$$(echo "$$name" | tr ' /' '_-' | tr -cd 'a-zA-Z0-9_-'); \
		PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -d postgres -t -A -c \
			"SELECT document.canvas_render_svg_mini('$$id'::uuid) FROM (SELECT set_config('app.tenant_id','dev',true)) _" \
			> "tmp/$$safe.svg"; \
		echo "  tmp/$$safe.svg"; \
	done
	@echo "Done"

export-pdf: export-svg ## Export all canvas as PDF (SVG → Chrome headless)
	@CHROME="$$(which google-chrome-stable 2>/dev/null || echo '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')"; \
	for f in tmp/*.svg; do \
		pdf="$${f%.svg}.pdf"; \
		"$$CHROME" --headless --disable-gpu --no-sandbox --print-to-pdf="$$pdf" --no-pdf-header-footer \
			"file://$$(cd . && pwd)/$$f" 2>/dev/null; \
		echo "  $$pdf ($$(du -h "$$pdf" | cut -f1))"; \
	done
	@echo "Done"
