# PLX Migration

## Objectif

Migrer un module legacy vers PLX sans perdre le metier important, mais sans forcer le compilateur a absorber chaque detail historique.

## Methode

1. Identifier les entites et leur frontiere publique.
2. Migrer le modele structurel dans PLX.
3. Recuperer le CRUD et les vues standards.
4. Rebrancher les invariants metier avec hooks et validations.
5. Rebrancher les enrichissements de lecture/liste avec `strategies.*`.
6. Garder le reste en fonctions manuelles ou `post_apply` si necessaire.

## Ce Qu'il Faut Preserver

- invariants metier
- transitions importantes
- read-models utiles
- agrégats qui changent vraiment l'usage
- i18n et seed versionnes

## Ce Qu'on Peut Simplifier Temporairement

- certains handlers legacy de convenance
- des projections non critiques
- des details de surface UI si le contrat SDUI evolue

## Ce Qui Doit Faire Remonter Un Besoin Compilateur

Un besoin doit remonter au compilateur si:

- il revient dans plusieurs modules
- il force un contournement laid ou fragile
- il abime la lisibilite du PLX
- il touche le contrat standard de creation, lecture, liste ou SDUI

Exemples typiques:

- hook de cycle de vie manquant
- type de champ ou action canonique absent
- drift entre SDUI front, runtime et PLX
- DDL structurel recurrent qui reste en `post_apply` sur plusieurs modules

## Read Model

Quand le legacy embarquait deja un read-model riche:

- ne pas essayer de tout remettre dans le CRUD auto-genere
- utiliser `strategies.read.query`
- utiliser `strategies.read.hateoas` pour les actions

## List Model

Quand le legacy avait deja une liste agregée:

- utiliser `strategies.list.query`
- garder la projection optimisee cote SQL

## Structure Hors Compilateur

Pour ce que le compilateur ne sait pas encore exprimer:

- `plx.post_apply` pour DDL complementaire idempotent
- helpers SQL manuels pour logique riche

Exemples:

- DDL vraiment hors subset supporte
- vues auxiliaires
- triggers techniques

Avant de conclure a un manque compilateur:

- verifier si `states` sait deja exprimer la transition voulue
- verifier si `generated` couvre deja la colonne derivee
- verifier si `indexes` couvre deja l'index recurrent

Exemples deja supportes:

- `submitted -> rejected` si `rejected` fait partie des etats declares
- colonne `GENERATED ALWAYS AS (...) STORED`
- index GIN simple
- index partiel avec `where`
- vues auxiliaires

## Critere De Parite Minimale

On peut considerer qu'un module est migré quand:

- il compile en PLX
- les tests passent
- les invariants metier critiques sont preserves
- les surfaces publiques pertinentes sont couvertes

Le but n'est pas la copie bit-a-bit du legacy.

## Critere D'Arret

Si la migration force des contournements repetes ou obscurs:

1. stopper la migration locale
2. identifier le manque du langage
3. corriger le compilateur
4. reprendre le module
