# Asset Migration Gaps

## Oublis de migration

- `asset.search()` a perdu le filtre `p_tags` présent dans le legacy SQL.
- Les tests PLX ne couvrent plus explicitement ce filtre, alors que le legacy le couvrait.

## Vrais manques plateforme

- `search_vec GENERATED ALWAYS` reste dans [plx/post_apply.sql](/Users/alexandreboyer/dev/projects/plpgsql-workbench/modules/asset/plx/post_apply.sql), car le compilateur ne sait pas encore générer ce type de colonne.
- Les index FTS/GIN associés restent aussi hors compilateur pour la meme raison.

## Lecture

- Le coeur du module est bien porté en PLX.
- Le reliquat principal n'est pas le CRUD mais le support des colonnes calculées/index FTS dans le DDL.
