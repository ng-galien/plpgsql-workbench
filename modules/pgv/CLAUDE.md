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

### Grants (DDL obligatoire)

Chaque `build/{schema}.ddl.sql` DOIT inclure :
- `GRANT USAGE ON SCHEMA {schema} TO web_anon;`
- `GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA {schema} TO web_anon;`
- `GRANT SELECT ON ALL TABLES IN SCHEMA {schema} TO web_anon;`

### Communication inter-modules

- `pg_msg_inbox module:pgv` → lire les messages entrants
- `pg_msg` → envoyer un message a un autre module
- Chaque module est autonome — ne jamais modifier les fonctions d'un autre module

## i18n

Le framework utilise `pgv.t(key)` pour l'internationalisation. Chaque module doit :
1. Créer `pgv.i18n_seed()` — INSERT INTO pgv.i18n(lang, key, value) les traductions FR
2. Clés namespaced : `pgv.nav_xxx`, `pgv.title_xxx`, `pgv.btn_xxx`, etc.
3. Utiliser `pgv.t('pgv.xxx')` dans nav_items(), brand(), et toutes les fonctions get_*/post_*
4. `ON CONFLICT DO NOTHING` dans le seed

## QA Seed Data

Le schema `pgv_qa` contient uniquement `seed()` et `clean()` — PAS de pages.
- `pgv_qa.seed()` — INSERT données démo réalistes
- `pgv_qa.clean()` — DELETE dans l'ordre inverse des FK
- `ON CONFLICT DO NOTHING`, penser multi-tenant (`current_setting('app.tenant_id', true)`)

## Workflow agent

1. Au démarrage ou quand on te dit "go" : **toujours lire `pg_msg_inbox module:pgv`**
2. Traiter les messages par priorité (HIGH d'abord)
3. Ne pas résoudre un message tant que la tâche n'est pas vérifiée
4. Après chaque tâche : `pg_pack schemas: pgv,pgv_ut,pgv_qa` (les 3 schemas)
5. Puis `pg_func_save target: plpgsql://pgv` + `plpgsql://pgv_ut` + `plpgsql://pgv_qa`

## Gotchas

- `call_ref()` ne fonctionne que dans le contexte `route()` (besoin de `pgv.route_prefix`)
- `route()` auto-prefixe les hrefs nav avec `/{schema}` — ne pas doubler dans `nav_items()`
- PicoCSS haute specificite — matcher leur pattern pour les `.pgv-*`
- PostgREST content negotiation — utiliser le domaine `"text/html"` pour les pages
- Inline styles interdit — `data-*` + JS dans `_enhance()` pour le dynamique
- POST retourne raw HTML (toast/redirect), jamais wrappe dans `page()`
