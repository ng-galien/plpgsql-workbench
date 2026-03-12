# project — Chantiers & Suivi Avancement

Module de gestion de chantiers pour ERP artisan. Suivi de projets, jalons, affectation ressources, facturation de situation (avancement BTP).

**Dépend de :** `pgv` (primitives UI), `crm` (table `crm.client`), `quote` (devis liés + factures de situation)

## Schemas

| Schema | Role | Contenu |
|--------|------|---------|
| `project` | Core + pages | Tables, helpers, pages, actions |
| `project_ut` | pgTAP tests | test_* functions |
| `project_qa` | QA seed data only | seed(), clean() |

## Layout

```
build/project.ddl.sql       # Schema + tables + triggers + grants
build/project.func.sql      # pg_pack output (project + project_ut, dependency-sorted)
src/project/*.sql           # Function sources (pg_func_save)
src/project_ut/test_*.sql   # Test sources (pg_func_save)
qa/project_qa/*.sql         # QA/demo sources (pg_func_save — _qa suffix -> qa/)
```

## Data Model

| Table | Purpose | Key columns |
|-------|---------|-------------|
| `project.chantier` | Chantiers/projets | nom, client_id FK crm.client, adresse, date_debut_prevue, date_fin_prevue, date_debut_reelle?, date_fin_reelle?, statut, notes |
| `project.jalon` | Jalons (milestones) | chantier_id FK CASCADE, nom, date_prevue, date_reelle?, pct_avancement, sort_order, notes |
| `project.situation` | Situations de facturation | chantier_id FK CASCADE, numero, date_situation, facture_id? FK quote.facture, notes |
| `project.situation_ligne` | Lignes de situation | situation_id FK CASCADE, devis_ligne_id FK quote.ligne, pct_cumule, montant_cumule, montant_precedent, montant_a_facturer |

### Politique NULL

`NOT NULL` par defaut. Exceptions justifiees :
- `chantier.date_debut_reelle` / `date_fin_reelle` — NULL = pas encore commence/termine
- `jalon.date_reelle` — NULL = jalon pas encore atteint
- `situation.facture_id` — NULL = situation pas encore facturee

### Relations FK

```
project.chantier.client_id -> crm.client(id)         -- sans CASCADE (client non supprimable si chantier existe)
project.jalon.chantier_id -> project.chantier(id)     -- CASCADE
project.situation.chantier_id -> project.chantier(id) -- CASCADE
project.situation.facture_id -> quote.facture(id)     -- sans CASCADE (facture immutable)
project.situation_ligne.situation_id -> project.situation(id) -- CASCADE
project.situation_ligne.devis_ligne_id -> quote.ligne(id)     -- sans CASCADE
```

## Multi-tenant (RLS)

Toutes les tables metier portent un `tenant_id` pour l'isolation multi-tenant.

| Table | Colonne | Default |
|-------|---------|---------|
| `project.chantier` | `tenant_id TEXT NOT NULL` | `current_setting('app.tenant_id', true)` |
| `project.jalon` | `tenant_id TEXT NOT NULL` | `current_setting('app.tenant_id', true)` |
| `project.situation` | `tenant_id TEXT NOT NULL` | `current_setting('app.tenant_id', true)` |
| `project.situation_ligne` | `tenant_id TEXT NOT NULL` | `current_setting('app.tenant_id', true)` |

RLS active sur les 4 tables :
```sql
CREATE POLICY tenant_isolation ON project.chantier
  USING (tenant_id = current_setting('app.tenant_id', true));
```

- En dev : `app.tenant_id = 'dev'`
- En prod : extrait du JWT
- Le tenant_id est sur chaque table car PostgREST peut query chaque table independamment

## Statuts chantier (lifecycle)

`planifie` -> `en_cours` -> `termine` -> `facture`

A tout moment : `annule` (depuis n'importe quel statut sauf `facture`).

Transitions strictes — RAISE EXCEPTION si :
- Transition invalide (ex: planifie -> termine directement)
- Facturation d'un chantier non termine
- Annulation d'un chantier deja facture

### Regles de transition

| Depuis | Vers autorise |
|--------|--------------|
| `planifie` | `en_cours`, `annule` |
| `en_cours` | `termine`, `annule` |
| `termine` | `facture`, `annule` |
| `facture` | *(aucun — etat final)* |
| `annule` | *(aucun — etat final)* |

Passage en `en_cours` : remplit `date_debut_reelle` si NULL.
Passage en `termine` : remplit `date_fin_reelle` si NULL.

## Facturation de situation (avancement BTP)

La facturation de situation est le mode standard en BTP. Elle facture un pourcentage d'avancement du devis par poste.

### Principe

Un chantier est lie a un ou plusieurs devis acceptes (via `quote.devis` avec `statut = 'accepte'`). Chaque situation represente un etat d'avancement a une date donnee.

### Calcul par ligne de situation

Pour chaque ligne de devis liee au chantier :

```sql
-- Pourcentage cumule d'avancement (saisi par l'artisan, ex: 60%)
pct_cumule := 60;

-- Montant cumule = % x montant HT de la ligne de devis
montant_cumule := ROUND(pct_cumule / 100.0 * montant_ht_devis, 2);

-- Montant deja facture = somme des montant_a_facturer des situations precedentes
montant_precedent := SUM(montant_a_facturer) FROM situations_precedentes;

-- Montant a facturer dans cette situation
montant_a_facturer := montant_cumule - montant_precedent;
```

### Regles

- `pct_cumule` est **croissant** — une situation N+1 ne peut pas avoir un % inferieur a la situation N
- `pct_cumule` est entre 0 et 100
- `montant_a_facturer` peut etre 0 (si aucun avancement sur cette ligne depuis la derniere situation)
- `montant_a_facturer` ne peut JAMAIS etre negatif (pas d'avoir en v0.1)
- **Arrondi par ligne** — coherent avec la regle du module quote : `ROUND(..., 2)` par ligne

### Generation de facture

Quand une situation est validee, elle genere une facture via le module `quote` :
1. Creer `quote.facture` avec `client_id` du chantier, objet = "Situation N - [nom chantier]"
2. Creer les `quote.ligne` correspondantes (une par ligne de situation avec `montant_a_facturer > 0`)
3. Stocker `facture_id` dans `project.situation`

## Lien devis

Un chantier est lie a un ou plusieurs devis acceptes. La liaison se fait via les lignes de devis qui alimentent les lignes de situation.

- Seuls les devis avec `statut = 'accepte'` peuvent etre lies a un chantier
- Les lignes de `situation_ligne` referencent directement `quote.ligne(id)` via `devis_ligne_id`

## Primitives pgView

| Primitive | Usage |
|-----------|-------|
| `pgv.stat()` | Dashboard KPIs (chantiers actifs, % avancement moyen, CA situe, prochains jalons) |
| `pgv.tabs()` | Fiche chantier (Jalons, Situations, Infos) |
| `pgv.dl()` | Header chantier (client, adresse, dates, statut) |
| `pgv.badge()` | Statuts : planifie=warning, en_cours=info, termine=success, facture=success, annule=danger |
| `pgv.breadcrumb()` | Navigation (Chantiers > Nom du chantier) |
| `pgv.action()` | Boutons lifecycle (conditionnel selon statut) |
| `pgv.md_table()` | Liste chantiers, tableau jalons, tableau situations, lignes de situation |
| `pgv.empty()` | Aucun chantier, aucun jalon |
| `pgv.href()` | Liens route-aware |
| `pgv.grid()` | Grille de stats dashboard |
| `pgv.card()` | Resume situation, prochains jalons |
| `pgv.alert()` | Avertissements (chantier en retard, jalon depasse) |
| `pgv.progress()` | Barre d'avancement chantier (si disponible, sinon badge %) |

Formulaire ajout jalon / nouvelle situation inline via `<details>`. Visible **uniquement si chantier non annule/facture**.

## Pages

| Fonction | Type | Description |
|----------|------|-------------|
| `get_dashboard()` | GET | Chantiers actifs, prochains jalons, KPIs |
| `get_chantiers()` | GET | Liste de tous les chantiers (filtrable par statut) |
| `get_chantier(p_id)` | GET | Fiche chantier : header + onglets (jalons, situations) |
| `get_chantier_form(p_id DEFAULT NULL)` | GET | Formulaire creation/edition chantier |
| `get_situation(p_id)` | GET | Detail d'une situation (lignes + montants) |
| `get_situation_form(p_chantier_id, p_id DEFAULT NULL)` | GET | Formulaire saisie avancement |
| `post_chantier_save(p_data)` | POST | Upsert chantier |
| `post_chantier_status(p_data)` | POST | Transition de statut |
| `post_chantier_delete(p_data)` | POST | Suppression (planifie uniquement) |
| `post_jalon_save(p_data)` | POST | Ajout/edition jalon |
| `post_jalon_delete(p_data)` | POST | Suppression jalon |
| `post_situation_save(p_data)` | POST | Saisie/validation situation + generation facture |
| `nav_items()` | - | Menu navigation |
| `brand()` | - | Nom module |

## Conventions

- **UI :** French — Chantier, Jalon, Situation, Avancement, Planifie, En cours, Termine, Facture, Annule, Date prevue, Date reelle, Progression
- **Pages GET** : `get_*()` retournent `"text/html"`, wrappees dans `pgv.page()`
- **Actions POST** : `post_*()` prennent `p_data jsonb`, retournent `<template data-redirect>` + `<template data-toast>`
- **Navigation** : `nav_items()` retourne `TABLE(label, href, icon)`, `brand()` retourne text
- **Formulaire unifie** : `get_chantier_form(p_id DEFAULT NULL)` — NULL = creation, id = edition pre-remplie
- **Upsert** : `post_chantier_save` — presence d'`id` dans jsonb determine INSERT vs UPDATE
- **Helpers prives** : prefixe `_` (ex: `_calcul_situation`, `_montant_precedent`) — fonctions internes, pas exposees en navigation

## Relations cross-module

| Module | Relation | Contrainte |
|--------|----------|------------|
| `crm` | `project.chantier.client_id -> crm.client(id)` | FK sans CASCADE — client non supprimable si chantier existe |
| `quote` | `project.situation_ligne.devis_ligne_id -> quote.ligne(id)` | FK sans CASCADE — ligne de devis non supprimable si situee |
| `quote` | `project.situation.facture_id -> quote.facture(id)` | FK sans CASCADE — facture immutable |

Consequence : `post_chantier_delete` doit catcher l'erreur FK et afficher un message clair. Seuls les chantiers `planifie` sans situations peuvent etre supprimes.

## File Export

- `project`, `project_ut` -> `src/`
- `project_qa` -> `qa/`
- **pg_pack :** `project,project_ut` (sans project_qa)

`_qa` dans `qa/` est normal et BY DESIGN. Ne PAS deplacer.

## Testing

```
pg_test target: "plpgsql://project_ut"
```

Tests critiques :
- **Lifecycle** : verifier chaque transition valide et invalide (planifie -> en_cours -> termine -> facture, annule depuis chaque etat)
- **Situation calcul** : verifier `montant_a_facturer = montant_cumule - montant_precedent`
- **Pct croissant** : verifier que `pct_cumule` ne peut pas diminuer entre deux situations
- **Arrondi par ligne** : coherent avec module quote, `SUM(ROUND(..., 2))` jamais `ROUND(SUM(...), 2)`
- **Generation facture** : verifier creation correcte de `quote.facture` + `quote.ligne` depuis situation
- **Immutabilite** : verifier qu'un chantier facture ne peut plus etre modifie/annule
- **FK cross-module** : verifier que les contraintes FK crm/quote bloquent les suppressions

## Review UI/UX

Quand toutes les pages sont fonctionnelles, envoyer une demande de review a l'agent pgv :

```
pg_msg from:project to:pgv type:question subject:"Review UI/UX pages Project"
```

L'agent pgv lancera `diagnose('project', '*')` et verifiera l'ergonomie, les primitives, et les conventions.

## Gotchas

- **Depend de CRM + Quote** — DDL reference `crm.client(id)` et `quote.facture(id)` / `quote.ligne(id)`, les deux modules doivent etre deployes avant
- **ARRONDI PAR LIGNE** — Coherent avec module quote. Toujours `SUM(ROUND(..., 2))`, jamais `ROUND(SUM(...), 2)`
- **Pct cumule croissant** — Une situation N+1 ne peut JAMAIS avoir un `pct_cumule` inferieur a la situation N pour la meme ligne de devis
- **Pas d'avoir** — v0.1 ne gere pas les avoirs. `montant_a_facturer` ne peut pas etre negatif.
- **Facture de situation immutable** — Une fois la facture generee via quote, elle suit les regles d'immutabilite du module quote (envoyee = jamais modifiable)
- **Pas de PDF** — hors scope v0.1, juste donnees + pages pgView
- **Pas de planification Gantt** — v0.1 = jalons simples avec dates, pas de diagramme de Gantt
- **Suppression chantier** — uniquement si `statut = 'planifie'` et aucune situation creee. Les chantiers avec situations/factures ne sont JAMAIS supprimables.
- **Client selector** — Le formulaire chantier doit proposer un selecteur de client depuis `crm.client`. Implementer via `<select>` peuple par requete sur `crm.client`.
- **Devis multiples** — Un chantier peut avoir plusieurs devis acceptes. Les lignes de situation referencent des lignes de devis individuelles, pas le devis entier.
