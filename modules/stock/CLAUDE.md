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

### Grants (DDL obligatoire)

Chaque `build/{schema}.ddl.sql` DOIT inclure :
- `GRANT USAGE ON SCHEMA {schema} TO web_anon;`
- `GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA {schema} TO web_anon;`
- `GRANT SELECT ON ALL TABLES IN SCHEMA {schema} TO web_anon;`

### Communication inter-modules

- `pg_msg_inbox module:stock` → lire les messages entrants
- `pg_msg` → envoyer un message a un autre module
- Chaque module est autonome — ne jamais modifier les fonctions d'un autre module

## Gotchas

- Mouvements INSERT only — jamais UPDATE/DELETE, correction par mouvement `inventaire`
- CRM doit etre deploye avant (fournisseurs = `crm.client` type company)
- Valorisation PMP : recalculee a chaque entree, figee a chaque sortie
- Multi-depots : stock = SUM(mouvements) GROUP BY article, depot
- Seuils d'alerte sur quantite minimale par article/depot

## Premier demarrage

Lire `pg_msg_inbox module:stock` pour les instructions d'implementation detaillees.
Consulter crm, quote, ledger comme reference pour les patterns pgView.
