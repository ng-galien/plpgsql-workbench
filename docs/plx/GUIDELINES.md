# PLX Guidelines

## Positionnement

PLX sert a decrire des modules metier autour d'un modele relationnel simple, d'un contrat SDUI et d'un workflow de compilation/release reproductible.

PLX n'est pas:

- un remplaçant total du SQL natif
- un DSL pour toute la logique applicative
- une abstraction qui doit absorber chaque cas legacy

La règle pratique est:

- declaratif d'abord
- point d'extension ensuite
- SQL manuel seulement en dernier recours

Si un contournement revient dans plusieurs modules, il faut faire evoluer PLX.

## Invariants

- `tenant_id` est un invariant de plateforme
- `id` est genere automatiquement par le compilateur
- `fields` est la seule facon de declarer les champs structures
- `payload` est optionnel et complete `fields`
- `columns` n'est plus une syntaxe du DSL
- une entite peut etre publique ou interne avec `expose: false`

## Public vs Interne

Par defaut, une entite PLX est publique:

- table
- `_view`
- `_list`
- `_read`
- `_create`
- `_update`
- `_delete`
- transitions publiques eventuelles

Utiliser `expose: false` quand la table doit exister mais ne doit pas devenir une ressource CRUD/SDUI navigable.

Cas typiques:

- lignes enfants d'un agregat
- tables techniques de support
- donnees manipulees seulement via une autre ressource metier

## Quand Rester Declaratif

Rester dans le genere tant que le besoin tient dans:

- `fields`
- `payload`
- `states`
- `view`
- `form`
- `actions`
- `validate create/update/delete`
- `before create/update`

Le genere est le bon choix quand:

- la lecture est essentiellement `to_jsonb(row)`
- la liste est essentiellement une projection simple
- les actions derivent du statut ou d'une regle simple
- les validations se basent sur `p_input` et `p_row`

## Quand Utiliser Un Point D'Extension

Utiliser un point d'extension quand le metier depasse le CRUD simple mais reste naturellement rattache a une entite.

Points d'extension a privilegier:

- `before create`
- `before update`
- `strategies.read.query`
- `strategies.read.hateoas`
- `strategies.list.query`
- `plx.post_apply`

Ne pas sortir trop vite du DSL si un point d'extension existe deja.

## Quand Accepter Du Manuel

Garder du SQL ou des fonctions manuelles quand le besoin est structurellement hors scope du genere.

Exemples:

- FTS avec colonne `GENERATED ALWAYS`
- index specifiques
- projections complexes ou optimisations lourdes
- logique de rejet/refus qui deborde la state machine actuelle
- fonctions runtime ou infrastructure

Le manuel doit alors etre clairement place:

- dans des helpers de module
- dans `post_apply`
- ou dans le runtime SQL natif

## SDUI

Le contrat canonique SDUI vit dans `runtime/sdui/schema`.

Regles pratiques:

- `_view()` decrit le contrat de vue
- `data.ui` est pertinent pour un detail single-row
- les listes ne doivent pas embarquer un arbre UI complet par ligne
- utiliser `select` avec `search: true`, pas `combobox`

## Tests

Preferer les appels PLX normaux quand ils sont supportes.

Eviter les triple-quoted `"""` seulement pour contourner:

- les named args
- l'inference de type
- les casts simples

Le SQL passthrough reste acceptable pour:

- une requete metier complexe
- une assertion SQL tres specifique
- un cas que le DSL ne modele pas encore

## Anti-patterns

- forcer tout le metier dans `_read()` ou `_list()` auto-generes au lieu d'utiliser `strategies.*`
- exposer en CRUD une table qui devrait etre interne
- utiliser `seed` pour du DDL structurel
- dupliquer un contrat SDUI cote front et cote PLX au lieu d'utiliser le schema canonique
- contourner durablement le DSL au lieu de faire remonter un manque recurrent

## Checklist

Avant de considerer un module PLX propre:

1. Les entites internes sont marquees `expose: false` si besoin.
2. Les invariants de creation/update passent par hooks ou validations, pas par contournements implicites.
3. Les enrichissements de lecture/liste passent par `strategies.*` quand c'est le bon niveau.
4. Les complements structurels hors compilateur sont dans `plx.post_apply`.
5. Le contrat SDUI emis reste compatible avec le schema canonique.
