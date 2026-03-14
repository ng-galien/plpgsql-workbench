# workbench — Platform Infrastructure & Tour de Controle

Schema fondation de la plateforme. Tables partagees (tenants, messaging, hooks, sessions, issues) + UI dashboard pour le PO.

**Depend de :** `pgv`

**Schemas :** `workbench` (public)

## Responsabilites

### Tables (DDL dans build/workbench.ddl.sql)

| Table | Role |
|-------|------|
| `toolbox` / `toolbox_tool` | Registre MCP tools (peuple par `npm run sync-tools`) |
| `tenant` / `tenant_module` | Multi-tenant + modules actifs par tenant (sort_order = ordre nav) |
| `config` | Config applicative key-value (zero env vars) |
| `agent_message` | Messaging inter-modules (pg_msg / pg_msg_inbox) |
| `agent_session` | Sessions agents Claude Code |
| `hook_log` | Audit des hooks de workflow |
| `issue_report` | Bug reports et feature requests (dispatch par le lead) |
| `gotcha` | Regles et pieges documentes par scope |

### Fonctions infra (pas de UI)

- `inbox_check()` / `inbox_new()` / `inbox_pending()` — API messaging interne
- `ack_resolved()` — auto-acknowledge messages resolus
- `api_hooks()` / `api_messages()` / `api_sessions()` — endpoints API ops
- `log_hook()` — audit hook calls
- `on_issue_report_insert()` — trigger notification issue
- `postgrest_pre_request()` — pre-request hook PostgREST
- `session_create()` / `session_end()` — lifecycle agent sessions

### Pages UI (pgView)

- `get_index()` — Dashboard: stats messages/issues, derniers messages, issues ouvertes
- `get_messages()` / `get_message(p_id)` — Liste et detail des messages inter-modules
- `get_issues()` — Liste des issue_report avec statut
- `get_tools()` — Catalogue MCP tools par pack (tree view)
- `get_tool(p_name)` — Detail d'un tool (description + parametres)
- `get_primitives()` — Catalogue UI wrappant les pages pgv_qa (composants, tables, formulaires, etc.)
- `nav_items()` / `brand()` / `i18n_seed()` — Navigation et i18n

## Framework pgView

Ce module est un **module independant** du framework pgView. Ses dependances sont declarees dans `module.json`.

### Conventions PL/pgSQL

- `get_*()` -> pages GET, `post_*()` -> actions POST. Nommage = routing automatique via `pgv.route()`
- `nav_items() -> jsonb` -> menu du module. Retourne `jsonb` (JAMAIS TABLE)
- `brand() -> text` -> nom affiche dans la nav
- `get_index()` -> page d'accueil du module (obligatoire)
- Parametres via query string : `/message?p_id=42` -> `get_message(p_id integer)`
- POST retourne raw HTML (templates `<template data-toast>` ou `<template data-redirect>`) — jamais wrappe dans `page()`
- Tables via `<md>` blocks (markdown), JAMAIS `<table>` HTML. `<md data-page="20">` pour pagination
- CSS classes `pgv-*`, JAMAIS de `style="..."` inline
- Primitives UI : `pgv.stat()`, `pgv.badge()`, `pgv.card()`, `pgv.grid()`, `pgv.empty()`, `pgv.md_table()`, `pgv.action()`, `pgv.tree()`, `pgv.md_esc()`

### Workflow dev (STRICT)

1. **DDL** -> Write dans `build/workbench.ddl.sql` -> `pg_schema` pour appliquer
2. **Fonctions** -> `pg_func_set` pour creer/modifier + `pg_test` pour valider
3. **Exporter** -> `pg_pack schemas:workbench` (-> `build/workbench.func.sql`) + `pg_func_save target:plpgsql://workbench` (-> `src/`)
4. `pg_query` -> SELECT/DML uniquement, JAMAIS de DDL ou CREATE FUNCTION
5. JAMAIS ecrire de fonctions dans des fichiers SQL — le workbench EST l'outil de dev
6. JAMAIS editer `build/*.func.sql` — genere par `pg_pack`

### Module structure

- `module.json` -> manifest (schemas, dependencies, extensions, sql, grants)
- `build/` -> artefacts de deploiement (DDL + fonctions packees)
- `src/` -> sources individuelles versionnees (pg_func_save)

### Contenu du DDL — STRICT

Le DDL (`build/{schema}.ddl.sql`) contient **uniquement de la structure** :

**DOIT contenir :** CREATE SCHEMA, CREATE TABLE, CREATE INDEX, constraints, RLS policies

**NE DOIT PAS contenir :**
- `CREATE FUNCTION` → pg_func_set puis pg_pack
- `CREATE TRIGGER` → pg_pack attache les triggers aux fonctions
- `GRANT` → pg_pack les ajoute dans .func.sql
- `INSERT INTO` (seed data) → `build/{schema}.seed.sql` ou `{schema}_qa.seed()`
