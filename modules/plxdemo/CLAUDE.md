# plxdemo

Description a completer.

**Depend de :** `pgv`

**Schemas :** `plxdemo`, `plxdemo_ut` (tests), `plxdemo_qa` (seed data)

## Framework pgView

Ce module est un **module independant** du framework pgView. Ses dependances sont declarees dans `module.json`.

### Conventions PL/pgSQL

- `get_*()` → pages GET, `post_*()` → actions POST. Nommage = routing automatique via `pgv.route()`
- `nav_items() -> jsonb` → menu du module. Retourne `jsonb` (JAMAIS TABLE)
- `brand() -> text` → nom affiche dans la nav
- `get_index()` → page d'accueil du module (obligatoire)
- Parametres via query string : `/page?p_id=42` → `get_page(p_id int)`
- POST retourne raw HTML (templates `<template data-toast>` ou `<template data-redirect>`) — jamais wrappe dans `page()`
- Tables via `<md>` blocks (markdown), JAMAIS `<table>` HTML. `<md data-page="20">` pour pagination
- CSS classes `pgv-*`, JAMAIS de `style="..."` inline
- Primitives UI : `pgv.stat()`, `pgv.badge()`, `pgv.card()`, `pgv.grid()`, `pgv.empty()`, `pgv.md_table()`, `pgv.action()`

### Workflow dev (STRICT)

1. **PLX** -> edit `src/plxdemo.plx`
2. **Build** -> `pgm module build plxdemo` to generate `build/plxdemo.ddl.sql`, `build/plxdemo.func.sql` and `build/plxdemo_ut.func.sql`
3. **Install/Deploy** -> `pgm app install` then `pgm app deploy --apply`
4. Use MCP tools for DB inspection/tests, but keep PLX as the source of truth
5. JAMAIS editer `build/*.ddl.sql`, `build/*.func.sql` ou `build/*_ut.func.sql` a la main

### Module structure

- `module.json` → manifest (schemas, dependencies, extensions, sql, grants)
- `build/` → artefacts de deploiement (DDL + fonctions packees)
- `src/plxdemo.plx` → source PLX du module (contrat + fonctions + tests)
- `_ut` schemas → tests pgTAP (`test_*()`)
- `_qa` schemas → seed data uniquement (`seed()`, `clean()`), PAS de pages

### Contenu du DDL (`build/{schema}.ddl.sql`) — STRICT

Le DDL contient **uniquement de la structure**. Ordre d'application des migrations :
```
1. Extensions     → dans la migration globale, PAS dans le DDL module
2. DDL            → CREATE SCHEMA, CREATE TABLE, indexes, constraints, RLS policies
3. Functions      → pg_pack genere build/{schema}.func.sql (+ triggers attaches)
4. Grants         → pg_pack les ajoute a la fin de chaque .func.sql
5. Seed referentiel → donnees de reference dans build/{schema}.seed.sql (optionnel)
```

**Le DDL DOIT contenir :**
- `CREATE SCHEMA IF NOT EXISTS {schema};`
- `CREATE TABLE`, `CREATE INDEX`, `ALTER TABLE ... ADD CONSTRAINT`
- `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` + `CREATE POLICY`

**Le DDL NE DOIT PAS contenir :**
- `CREATE FUNCTION` → va dans les fonctions (pg_func_set → pg_pack)
- `CREATE TRIGGER` → pg_pack l'attache apres la fonction trigger dans .func.sql
- `GRANT` → pg_pack les ajoute a la fin de chaque .func.sql
- `INSERT INTO` → les donnees de reference vont dans `build/{schema}.seed.sql`
- Donnees de demo → vont dans `{schema}_qa.seed()`

### Donnees de reference (`build/{schema}.seed.sql`)

Certains modules ont des donnees de reference necessaires au fonctionnement :
- Plan comptable (ledger), categories par defaut (catalog), cles i18n (pgv)
- Ces donnees sont **partagees entre tous les tenants** (`tenant_id IS NULL` ou omis)
- Elles vivent dans `build/{schema}.seed.sql`, PAS dans le DDL
- Convention : `INSERT ... ON CONFLICT DO NOTHING` (idempotent)
- Ce fichier est reference dans `module.json` sql array, APRES le .func.sql

### Communication inter-modules

- `pg_msg_inbox module:plxdemo` → lire les messages entrants
- `pg_msg` → envoyer un message a un autre module
- Chaque module est autonome — ne jamais modifier les fonctions d'un autre module

## i18n

Le framework utilise `pgv.t(key)` pour l'internationalisation. Chaque module doit :
1. Créer `plxdemo.i18n_seed()` — INSERT INTO pgv.i18n(lang, key, value) les traductions FR
2. Clés namespaced : `plxdemo.nav_xxx`, `plxdemo.title_xxx`, `plxdemo.btn_xxx`, etc.
3. Utiliser `pgv.t('plxdemo.xxx')` dans nav_items(), brand(), et toutes les fonctions get_*/post_*
4. `ON CONFLICT DO NOTHING` dans le seed

## QA Seed Data

Le schema `plxdemo_qa` contient uniquement `seed()` et `clean()` — PAS de pages.
- `plxdemo_qa.seed()` — INSERT données démo réalistes
- `plxdemo_qa.clean()` — DELETE dans l'ordre inverse des FK
- `ON CONFLICT DO NOTHING`, penser multi-tenant (`current_setting('app.tenant_id', true)`)

## Workflow agent

1. Au démarrage ou quand on te dit "go" : **toujours lire `pg_msg_inbox module:plxdemo`**
2. Traiter les messages par priorité (HIGH d'abord)
3. Ne pas résoudre un message tant que la tâche n'est pas vérifiée
4. Après chaque tâche : `pg_pack schemas: plxdemo,plxdemo_ut,plxdemo_qa` (les 3 schemas)
5. Puis `pg_func_save target: plpgsql://plxdemo` + `plpgsql://plxdemo_ut` + `plpgsql://plxdemo_qa`

## Documentation intégrée

Le workbench embarque de la documentation accessible via `pg_doc` :
- `pg_doc topic:testing` — Guide pgTAP : conventions test_*(), assertions, patterns
- `pg_doc topic:data-convention` — Convention data_*() : cursor pagination, FTS, pgv.table()
- `pg_doc topic:coverage` — Guide couverture de code

## Gotchas

- **tenant_id** : toujours `PERFORM set_config('app.tenant_id', 'test', true)` au début de chaque test
- **pg_test** : découvre les fonctions `test_*()` dans le schema `_ut` — utiliser `pg_test schema:plxdemo_ut`
- (a completer au fil du developpement)

## Premier demarrage

Lire `pg_msg_inbox module:plxdemo` pour les instructions d'implementation detaillees.
Consulter crm, quote, ledger comme reference pour les patterns pgView.
