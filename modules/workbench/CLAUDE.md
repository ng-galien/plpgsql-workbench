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

### Grants (DDL obligatoire)

`build/workbench.ddl.sql` DOIT inclure :
- `GRANT USAGE ON SCHEMA workbench TO web_anon;`
- `GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA workbench TO web_anon;`
- `GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA workbench TO web_anon;`
- `GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA workbench TO web_anon;`

### Communication inter-modules

- `pg_msg_inbox module:workbench` -> lire les messages entrants
- `pg_msg` -> envoyer un message a un autre module
- **feature_request / bug_report -> TOUJOURS via issue_report** : ne jamais envoyer de feature_request ou bug_report directement a un autre module
- Chaque module est autonome — ne jamais modifier les fonctions d'un autre module

## i18n

Le framework utilise `pgv.t(key)` pour l'internationalisation :
1. `workbench.i18n_seed()` — INSERT INTO pgv.i18n(lang, key, value)
2. Cles namespaced : `workbench.nav_xxx`, `workbench.title_xxx`, `workbench.stat_xxx`, etc.
3. `ON CONFLICT DO NOTHING` dans le seed

## Workflow agent

1. Au demarrage ou quand on te dit "go" : **toujours lire `pg_msg_inbox module:workbench`**
2. Traiter les messages par priorite (HIGH d'abord)
3. Ne pas resoudre un message tant que la tache n'est pas verifiee
4. Apres chaque tache : `pg_pack schemas:workbench` + `pg_func_save target:plpgsql://workbench`

## Relation avec seed/003_workbench.sql

Le seed est le **bootstrap minimal** — il cree le schema + les tables de base + insere les donnees dev (tenant, tenant_module). Les fonctions sont dans le module (`build/workbench.func.sql`), PAS dans le seed.

## Gotchas

- **Tu es l'agent workbench, PAS le lead.** Ne jamais utiliser `ws_health` pour trouver tes tâches — il montre TOUTES les tasks du workspace. Utiliser uniquement `pg_msg_inbox module:workbench` pour lire TES messages. Ne traiter que les messages adressés à `workbench`.
- workbench ne possede PAS de schema _ut ni _qa — les tests sont dans ops_ut
- `get_primitives()` switch le `pgv.route_prefix` vers `/pgv_qa` pour que les `call_ref()` internes des fonctions pgv_qa resolvent correctement
- `pgv.md_esc()` est obligatoire pour tout contenu texte libre dans les cellules markdown (subject, body, resolution, description) — sinon les pipes et newlines cassent le tableau
- Les messages inter-modules sont dans `workbench.agent_message` — ops lit cette table aussi (lecture croisee)
- `tenant_module.sort_order` controle l'ordre du menu top-level dans le shell
