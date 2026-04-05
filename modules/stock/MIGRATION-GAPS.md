# Stock Migration Gaps

## Oublis de migration

- `article_delete` et `warehouse_delete` sont des soft deletes (`active=false`) comme dans le legacy.
  Les fonctions PLX générées sont surchargées manuellement — pattern identique à `client_archive` dans crm.
  L'historique des mouvements est préservé. La suppression physique reste bloquée par la FK.

- La double surface `depot_*` / `warehouse_*` du legacy (même table, deux noms) est consolidée sur `warehouse`.
  Aucune fonction `depot_*` n'est exposée — casse potentielle si un frontend l'appelle encore.

- `stock._recalc_pmp` (French legacy) supprimé — remplacé par `_recalc_wap` (English). Même logique.

- `stock._stock_actuel` (French alias) supprimé — remplacé par `_current_stock`.

- `entree_reception` (French, utilise `stock.mouvement` + `stock.depot`) supprimé — remplacé par `purchase_reception`.

## Vrais manques plateforme

- `_current_stock(article_id int, warehouse_id int?)` : le paramètre optionnel `int?` ne génère pas `DEFAULT NULL`.
  Workaround : appels explicites avec `NULL::int` dans les stratégies. À remonter au compilateur.

- `::int` dans les expressions PLX génère `::v_int` (variable locale) au lieu du cast SQL.
  Workaround : utiliser `::integer` (nom long). À corriger dans le codegen.

- `bool` comme type de variable locale n'est pas bien résolu par PLX (génère des erreurs de type).
  Workaround : utiliser un `int` compteur (`wh_count = 0`) à la place d'un booléen.

## Lecture

- `stock` valide le modèle PLX sur un module avec journal INSERT-ONLY, relations cross-module (crm.client),
  et opérations métier enrichies (`purchase_reception`).
- Les trois workarounds ci-dessus sont des bugs PLX reproductibles — bons candidats pour le compiler.
- La migration débloque `purchase` (qui dépend de `stock`).
