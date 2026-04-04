# PLX Patterns

## Entite CRUD Standard

Utiliser une entite publique simple quand le module peut vivre sur le flux genere.

```plx
entity crm.category:
  fields:
    name text required
    code text? unique
```

Bon fit:

- referentiel simple
- lecture directe
- peu d'agregations

## Entite Interne

Quand une table doit exister sans surface publique:

```plx
entity expense.line:
  expose: false

  fields:
    report_id int required ref(expense.expense_report)
    label text required
```

Ce que l'on garde:

- DDL
- autorisations de base

Ce qui disparait:

- `_view`
- `_list`
- `_read`
- `_create`
- `_update`
- `_delete`

## Before Create

Utiliser `before create` pour preparer `p_row` avant merge du `p_input`.

```plx
before create:
  if p_row.reference is null:
    p_row := jsonb_populate_record(
      p_row,
      {reference: expense._next_reference()}
    )
```

Bon fit:

- reference auto
- valeurs derivees
- pre-remplissage conditionnel

## Validation

Utiliser `validate create/update/delete` pour les regles d'integrite metier.

```plx
validate:
  date_order: """
    (p_input->>'end_date')::date >= (p_input->>'start_date')::date
  """
```

Bon fit:

- contraintes metier
- controle des transitions
- coherence inter-champs

## Read Query

Utiliser `strategies.read.query` quand le detail doit etre enrichi.

```plx
strategies:
  read.query: expense.expense_report_read_model
```

Bon fit:

- lignes embarquees
- totaux calcules
- projection read-model metier

## Read Hateoas

Utiliser `strategies.read.hateoas` quand les actions doivent etre calculees metier.

```plx
strategies:
  read.hateoas: expense.expense_report_actions
```

Bon fit:

- actions conditionnelles
- actions dependantes du contenu
- logique plus riche que la state machine standard

## List Query

Utiliser `strategies.list.query` quand la liste a besoin d'agregats.

```plx
strategies:
  list.query: expense.expense_report_list_model
```

Bon fit:

- `count(lines)`
- `sum(total)`
- projection compacte optimisee

## State Machine Simple

Utiliser `states` pour les transitions lineaires et lisibles.

```plx
states draft -> submitted -> validated -> reimbursed:
  submit(draft -> submitted)
  validate(submitted -> validated)
  reimburse(validated -> reimbursed)
```

Bon fit:

- workflow principal
- transitions sans embranchements complexes

## Rejet Manuel

Quand la state machine actuelle ne sait pas exprimer le cas:

```plx
fn expense.expense_report_reject(p_id text) -> jsonb [definer]:
  ...
```

Acceptable si:

- le pattern reste marginal
- la branche manquante n'est pas encore un besoin recurrent

## Post Apply

Utiliser `plx.post_apply` pour les complements structurels hors compilateur.

Bon fit:

- colonne `GENERATED ALWAYS`
- index specifiques
- vues auxiliaires
- backfill leger idempotent

A eviter:

- seed de donnees metier
- logique qui devrait etre dans le DDL genere

## SDUI

Rappels:

- `view` pour le contrat de vue
- `form` pour les champs d'edition
- `actions` pour le vocabulaire d'actions
- `data.ui` surtout pour les details

Pour les listes:

- decrire la structure
- ne pas embarquer un arbre UI complet sur chaque row
