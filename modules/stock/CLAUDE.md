# stock — Gestion des Stocks

Articles, mouvements entrees/sorties, multi-depots, seuils d'alerte, valorisation PMP.

**Depend de :** `pgv`, `crm`

**Schemas :** `stock`, `stock_ut` (tests), `stock_qa` (seed data)

## Framework pgView

Ce module est un **module independant** du framework pgView. Ses dependances sont declarees dans `module.json`.

### Conventions PL/pgSQL

- `get_*()` → pages GET, `post_*()` → actions POST. Nommage = routing automatique via `pgv.route()`
- `nav_items() -> jsonb` → menu du module. Retourne `jsonb` (JAMAIS TABLE)
- `brand() -> text` → nom affiche dans la nav
- `get_index()` → page d'accueil du module (obligatoire)
- Parametres via query string : `/article?p_id=42` → `get_article(p_id int)`
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

- `pg_msg_inbox module:stock` → lire les messages entrants
- `pg_msg` → envoyer un message a un autre module
- **feature_request / bug_report → TOUJOURS via issue_report** : ne jamais envoyer de feature_request ou bug_report directement à un autre module. Créer une issue : `INSERT INTO workbench.issue_report(issue_type, module, description) VALUES ('enhancement|bug', '<module_cible>', '<description>')`. Le lead sera notifié et décidera du dispatch.
- Chaque module est autonome — ne jamais modifier les fonctions d'un autre module

## i18n

Le framework utilise `pgv.t(key)` pour l'internationalisation. Chaque module doit :
1. Créer `stock.i18n_seed()` — INSERT INTO pgv.i18n(lang, key, value) les traductions FR
2. Clés namespaced : `stock.nav_xxx`, `stock.title_xxx`, `stock.btn_xxx`, etc.
3. Utiliser `pgv.t('stock.xxx')` dans nav_items(), brand(), et toutes les fonctions get_*/post_*
4. `ON CONFLICT DO NOTHING` dans le seed

## QA Seed Data

Le schema `stock_qa` contient uniquement `seed()` et `clean()` — PAS de pages.
- `stock_qa.seed()` — INSERT données démo réalistes
- `stock_qa.clean()` — DELETE dans l'ordre inverse des FK
- `ON CONFLICT DO NOTHING`, penser multi-tenant (`current_setting('app.tenant_id', true)`)

## Workflow agent

1. Au démarrage ou quand on te dit "go" : **toujours lire `pg_msg_inbox module:stock`**
2. Traiter les messages par priorité (HIGH d'abord)
3. Ne pas résoudre un message tant que la tâche n'est pas vérifiée
4. Après chaque tâche : `pg_pack schemas: stock,stock_ut,stock_qa` (les 3 schemas)
5. Puis `pg_func_save target: plpgsql://stock` + `plpgsql://stock_ut` + `plpgsql://stock_qa`


## Documentation intégrée

Le workbench embarque de la documentation accessible via `pg_doc` :
- `pg_doc topic:testing` — Guide pgTAP : conventions test_*(), assertions, patterns
- `pg_doc topic:data-convention` — Convention data_*() : cursor pagination, FTS, pgv.table()
- `pg_doc topic:coverage` — Guide couverture de code

## Gotchas

- **tenant_id** : toujours `PERFORM set_config('app.tenant_id', 'test', true)` au début de chaque test
- **pg_test** : découvre les fonctions `test_*()` dans le schema `_ut`

- **Tu es l'agent stock, PAS le lead.** Ne jamais utiliser `ws_health` pour trouver tes tâches — il montre TOUTES les tasks du workspace. Utiliser uniquement `pg_msg_inbox module:stock` pour lire TES messages. Ne traiter que les messages adressés à `stock`.
- Mouvements INSERT only — jamais UPDATE/DELETE, correction par mouvement `inventaire`
- CRM doit etre deploye avant (fournisseurs = `crm.client` type company)
- Valorisation PMP : recalculee a chaque entree, figee a chaque sortie
- Multi-depots : stock = SUM(mouvements) GROUP BY article, depot
- Seuils d'alerte sur quantite minimale par article/depot

## Premier demarrage

Lire `pg_msg_inbox module:stock` pour les instructions d'implementation detaillees.
Consulter crm, quote, ledger comme reference pour les patterns pgView.
