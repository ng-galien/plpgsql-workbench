# Catalog Migration Gaps

## Oublis de migration

- `catalog.article` garde des `actions` statiques alors que le legacy rendait `activate` / `deactivate` de façon conditionnelle selon `active`.
  Le bon portage passe par `read.hateoas`.
- `catalog.category` n'a pas de `list.query`, alors que le legacy enrichissait la liste avec `parent_name` et `article_count`.
- Une partie des anciens tests `*_read_hateoas` et de liste enrichie n'a pas encore été re-portée dans les specs PLX.

## Vrais manques plateforme

- Aucun manque bloquant identifié pour le portage principal.
- Les besoins observés rentrent déjà dans les points d'extension existants:
  - `read.query`
  - `read.hateoas`
  - `list.query`

## Lecture

- `catalog` valide plutôt bien le modèle actuel de PLX.
- Les écarts restants ressemblent surtout à des oublis de migration, pas à une limite du compilateur.
