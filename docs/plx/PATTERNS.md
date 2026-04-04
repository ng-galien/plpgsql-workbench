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

Utiliser `states` pour les transitions lisibles, y compris avec branches simples si tous les etats sont declares.

```plx
states draft -> submitted -> validated -> reimbursed -> rejected:
  submit(draft -> submitted)
  validate(submitted -> validated)
  reject(submitted -> rejected)
  reimburse(validated -> reimbursed)
```

Bon fit:

- workflow principal
- transitions simples et explicites
- branches metier courtes quand l'etat cible est declare

Limite actuelle:

- pas de DSL plus riche pour modeliser des graphes d'etats complexes ou des meta-donnees de transition plus poussees

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

## SQL Expert De Module

Utiliser `plx.sqlLib` quand un module garde un noyau SQL specialise que le PLX ne doit pas absorber.

Exemple manifeste:

```json
{
  "plx": {
    "entry": "plx/cad.plx",
    "sqlLib": [
      "plx/sql/measure.sql",
      "plx/sql/render_svg.sql",
      "plx/sql/scene_json.sql"
    ],
    "seed": "plx/seed.sql",
    "post_apply": "plx/post_apply.sql"
  }
}
```

Bon fit:

- fonctions SQL expertes appelees depuis la facade PLX
- geometrie, rendu, calculs metier tres specialises
- bibliotheque SQL stable qu'on veut garder dans le module

A eviter:

- l'utiliser pour du seed
- l'utiliser pour des complements qui doivent explicitement tourner apres l'apply principal
- y remettre du DDL simple que `generated` ou `indexes` savent deja exprimer

## Colonnes Generees

Utiliser `generated:` quand une colonne derivee revient dans le schema relationnel lui-meme.

```plx
generated:
  amount_incl_tax numeric(12,2): amount_excl_tax + vat

  search_vec tsvector: """
    setweight(to_tsvector('simple', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(description, '')), 'B')
  """
```

Bon fit:

- colonnes `GENERATED ALWAYS`
- FTS derive du contenu
- calculs persistants portes par PostgreSQL

Limite actuelle:

- seulement `GENERATED ALWAYS AS (...) STORED`
- pas encore de modelisation plus riche autour des options de colonne PostgreSQL

## Index Declaratifs

Utiliser `indexes:` pour les index recurrents lies a l'entite.

```plx
indexes:
  search:
    using: gin
    on: [search_vec]

  barcode:
    on: [barcode]
    where: barcode IS NOT NULL

  title_fts:
    using: gin
    on: [to_tsvector('french', coalesce(title, ''))]
```

Bon fit:

- GIN/GIST recurrents
- index partiels simples
- index FTS repetes sur plusieurs modules

Limite actuelle:

- pas de modelisation exhaustive de tous les index PostgreSQL
- si l'index devient trop exotique, garder `plx.post_apply`

## SDUI

Rappels:

- `view` pour le contrat de vue
- `form` pour les champs d'edition
- `actions` pour le vocabulaire d'actions
- `data.ui` surtout pour les details

Pour les listes:

- decrire la structure
- ne pas embarquer un arbre UI complet sur chaque row
