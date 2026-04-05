# Catalog Migration Gaps

## Oublis de migration — FERMÉS

- `catalog.article` : HATEOAS conditionnel (`activate`/`deactivate` selon `active`) — implémenté via `read.hateoas: catalog._article_hateoas`. Testé.
- `catalog.category` : `list.query` enrichi avec `parent_name` et `article_count` — implémenté via `list.query: catalog._category_list_query`. Testé.
- Tests HATEOAS et liste enrichie re-portés dans les specs PLX (40 tests, 0 failing).

## Vrais manques plateforme

- Aucun manque bloquant identifié.

## Workarounds PLX confirmés

- Dans les tests, `SELECT r FROM setof_fn() r` infère `record` pour la variable PLX → l'assert `->>` échoue.
  Workaround : `SELECT to_jsonb(r) FROM setof_fn() r` pour forcer le type jsonb.
  Pattern identique à `::integer` vs `::int` dans le codegen.

## Lecture

- `catalog` valide le modèle PLX sur un module avec hiérarchie (category parent/child),
  relations cross-module (stock, quote, purchase), et HATEOAS conditionnel sur état boolean.
- Consommé par : stock (catalog_article_id), quote (line items), purchase (order lines).
