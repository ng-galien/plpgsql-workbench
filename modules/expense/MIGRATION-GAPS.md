# Expense Migration Gaps

## Oublis de migration

- `expense.line` est marqué `expose: false` mais reste encore exporté dans [plx/expense.plx](/Users/alexandreboyer/dev/projects/plpgsql-workbench/modules/expense/plx/expense.plx).
- Une partie des anciens tests legacy autour du workflow métier riche n'a pas encore été re-portée en specs PLX.

## Vrais manques plateforme

- La state machine actuelle couvre bien les enchainements linéaires, mais pas proprement les branches métier comme `submitted -> rejected`.
- Le rejet reste donc manuel dans `helpers.plx`, ce qui signale un vrai besoin d'évolution du langage.

## Déjà couvert par la plateforme

- `_next_reference()` peut maintenant être porté proprement via `before create`.
- Le détail enrichi, les totaux et les actions conditionnelles passent déjà par:
  - `read.query`
  - `read.hateoas`
  - `list.query`

## Lecture

- `expense` montre surtout que la prochaine vraie évolution du compilateur est la state machine, pas le CRUD enrichi.
