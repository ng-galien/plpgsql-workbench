# pgv — pgView SSR Framework

Framework SSR PostgreSQL. Alpine.js shell + PicoCSS + PostgREST + primitives UI `pgv.*`.

**Depend de :** rien (module fondation)

**Schemas :** `pgv`, `pgv_ut` (tests + `assert_page()`), `pgv_qa` (demo app)

**Role special :** Referent UI/UX pour tous les modules (review via `diagnose()`)

## Framework pgView

Ce module EST le framework pgView — il fournit les primitives utilisees par tous les autres modules.

### Conventions PL/pgSQL

- `get_*()` → pages GET, `post_*()` → actions POST. Nommage = routing automatique via `pgv.route()`
- `nav_items() -> jsonb` → menu du module. Retourne `jsonb` (JAMAIS TABLE)
- `brand() -> text` → nom affiche dans la nav
- `get_index()` → page d'accueil du module (obligatoire)
- Parametres via query string : `/drawing?p_id=42` → `get_drawing(p_id int)`
- POST retourne raw HTML (templates `<template data-toast>` ou `<template data-redirect>`) — jamais wrappe dans `page()`
- Tables via `<md>` blocks (markdown), JAMAIS `<table>` HTML. `<md data-page="20">` pour pagination
- CSS classes `pgv-*`, JAMAIS de `style="..."` inline
- Primitives UI : `pgv.stat()`, `pgv.badge()`, `pgv.card()`, `pgv.grid()`, `pgv.empty()`, `pgv.md_table()`, `pgv.action()`

### Workflow dev (STRICT)

1. **DDL** → Write dans `build/{schema}.ddl.sql` → `pg_schema` pour appliquer
2. **Fonctions** → `pg_func_set` pour creer/modifier + `pg_test` pour valider
3. **Exporter** → `pg_pack` (→ `build/{schema}.func.sql`) + `pg_func_save` (→ `src/`)
4. `pg_query` → SELECT/DML uniquement, JAMAIS de DDL ou CREATE FUNCTION
5. JAMAIS ecrire de fonctions dans des fichiers SQL — le workbench EST l'outil de dev
6. JAMAIS editer `build/*.func.sql` — genere par `pg_pack`

### Module structure

- `module.json` → manifest (schemas, dependencies, extensions, sql, grants)
- `build/` → artefacts de deploiement (DDL + fonctions packees)
- `src/` → sources individuelles versionnees (pg_func_save)
- `_ut` schemas → tests pgTAP (`test_*()`)
- `_qa` schemas → seed data uniquement (`seed()`, `clean()`), PAS de pages

### Contenu du DDL — STRICT

Le DDL (`build/{schema}.ddl.sql`) contient **uniquement de la structure** :

**DOIT contenir :** CREATE SCHEMA, CREATE TABLE, CREATE INDEX, constraints, RLS policies

**NE DOIT PAS contenir :**
- `CREATE FUNCTION` → pg_func_set puis pg_pack
- `CREATE TRIGGER` → pg_pack attache les triggers aux fonctions
- `GRANT` → pg_pack les ajoute dans .func.sql
- `INSERT INTO` (seed data) → `build/{schema}.seed.sql` ou `{schema}_qa.seed()`

### Communication inter-modules

- `pg_msg_inbox module:pgv` → lire les messages entrants
- `pg_msg` → envoyer un message a un autre module
- **feature_request / bug_report → TOUJOURS via issue_report** : ne jamais envoyer de feature_request ou bug_report directement à un autre module. Créer une issue : `INSERT INTO workbench.issue_report(issue_type, module, description) VALUES ('enhancement|bug', '<module_cible>', '<description>')`. Le lead sera notifié et décidera du dispatch.
- Chaque module est autonome — ne jamais modifier les fonctions d'un autre module

## i18n

Le framework utilise `pgv.t(key)` pour l'internationalisation. Chaque module doit :
1. Créer `pgv.i18n_seed()` — INSERT INTO pgv.i18n(lang, key, value) les traductions FR
2. Clés namespaced : `pgv.nav_xxx`, `pgv.title_xxx`, `pgv.btn_xxx`, etc.
3. Utiliser `pgv.t('pgv.xxx')` dans nav_items(), brand(), et toutes les fonctions get_*/post_*
4. `ON CONFLICT DO NOTHING` dans le seed

## QA Seed Data

Le schema `pgv_qa` est le **design system showcase** — il contient des pages de démonstration de toutes les primitives pgv :
- `get_atoms()` — badges, stats, cards, dl, money, alerts, progress, workflow, avatar, tabs, accordion, breadcrumb, timeline, tree
- `get_tables()` — tables markdown simples, paginées, md_table()
- `get_forms()` — formulaires data-rpc, select_search, inputs, boutons d'action
- `get_dialogs()` — confirmations, modales, toasts
- `get_svg()` — svg_canvas avec toolbar zoom/pan
- `get_errors()` — gestion erreurs 404, RAISE, bad cast
- `get_diagnostics()` — exécute pgv.diagnose() sur toutes les pages QA
- `seed()` / `clean()` — données démo pour les tables QA
- Ces pages sont accessibles via workbench (Primitives tab) qui wrape les fonctions pgv_qa

## Workflow agent

1. Au démarrage ou quand on te dit "go" : **toujours lire `pg_msg_inbox module:pgv`**
2. Traiter les messages par priorité (HIGH d'abord)
3. Ne pas résoudre un message tant que la tâche n'est pas vérifiée
4. Après chaque tâche : `pg_pack schemas: pgv,pgv_ut,pgv_qa` (les 3 schemas)
5. Puis `pg_func_save target: plpgsql://pgv` + `plpgsql://pgv_ut` + `plpgsql://pgv_qa`


## Documentation intégrée

Le workbench embarque de la documentation accessible via `pg_doc` :
- `pg_doc topic:testing` — Guide pgTAP : conventions test_*(), assertions, patterns
- `pg_doc topic:data-convention` — Convention data_*() : cursor pagination, FTS, pgv.table()
- `pg_doc topic:coverage` — Guide couverture de code

## Gotchas

- **tenant_id** : toujours `PERFORM set_config('app.tenant_id', 'test', true)` au début de chaque test
- **pg_test** : découvre les fonctions `test_*()` dans le schema `_ut`

- **Tu es l'agent pgv, PAS le lead.** Ne jamais utiliser `ws_health` pour trouver tes tâches — il montre TOUTES les tasks du workspace. Utiliser uniquement `pg_msg_inbox module:pgv` pour lire TES messages. Ne traiter que les messages adressés à `pgv`.
- `call_ref()` ne fonctionne que dans le contexte `route()` (besoin de `pgv.route_prefix`)
- `route()` auto-prefixe les hrefs nav avec `/{schema}` — ne pas doubler dans `nav_items()`
- PicoCSS haute specificite — matcher leur pattern pour les `.pgv-*`
- PostgREST content negotiation — utiliser le domaine `"text/html"` pour les pages
- Inline styles interdit — `data-*` + JS dans `_enhance()` pour le dynamique
- POST retourne raw HTML (toast/redirect), jamais wrappe dans `page()`
