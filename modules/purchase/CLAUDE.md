# purchase — Commandes Fournisseurs

Module achats pour ERP artisan francais. Bons de commande fournisseurs, reception de marchandises (partielle ou totale), rapprochement factures fournisseurs.

**Depend de :** `pgv` (primitives UI), `crm` (fournisseurs = `crm.client` WHERE `type='company'`), `stock` (articles, mouvements)

## Schemas

| Schema | Role | Contenu |
|--------|------|---------|
| `purchase` | Core achats + pages | Tables, helpers, pages, actions |
| `purchase_ut` | pgTAP tests | test_* functions |
| `purchase_qa` | QA seed data only | seed(), clean() |

## Layout

```
build/purchase.ddl.sql        # Schema + tables + triggers + grants
build/purchase.func.sql       # pg_pack output (purchase + purchase_ut, dependency-sorted)
src/purchase/*.sql            # Function sources (pg_func_save)
src/purchase_ut/test_*.sql    # Test sources (pg_func_save)
qa/purchase_qa/*.sql          # QA/demo sources (pg_func_save — _qa suffix -> qa/)
```

## Data Model

| Table | Purpose | Key columns |
|-------|---------|-------------|
| `purchase.commande` | Bon de commande | numero UNIQUE, fournisseur_id FK crm.client, objet, statut, notes, date_livraison_prevue? |
| `purchase.commande_ligne` | Lignes de commande | commande_id FK CASCADE, article_id FK stock.article, sort_order, description, quantite, prix_unitaire, tva_rate |
| `purchase.reception` | Reception de marchandises | commande_id FK, numero_bl (bon de livraison fournisseur), date_reception, notes |
| `purchase.reception_ligne` | Lignes recues | reception_id FK CASCADE, commande_ligne_id FK, quantite_recue |
| `purchase.facture_fournisseur` | Facture fournisseur recue | commande_id? FK, numero_facture (ref fournisseur), date_facture, montant_ht, montant_tva, montant_ttc, statut, notes |

### Politique NULL

`NOT NULL` par defaut. Exceptions justifiees :
- `commande.date_livraison_prevue` — NULL = pas de date prevue communiquee
- `facture_fournisseur.commande_id` — NULL = facture sans commande prealable (achat direct)
- `commande.notes`, `reception.notes`, `facture_fournisseur.notes` — default `''` (jamais NULL)

### Fournisseurs

Les fournisseurs sont des `crm.client` avec `type = 'company'`. Pas de table fournisseur separee — le CRM est le referentiel unique. Le champ `commande.fournisseur_id` est une FK vers `crm.client(id)` sans CASCADE (un fournisseur avec commandes ne peut PAS etre supprime).

### Articles

Les articles sont dans `stock.article`. Le champ `commande_ligne.article_id` est une FK vers `stock.article(id)`. La description de la ligne est copiee depuis l'article a la creation (denormalisee pour historique).

## Multi-tenant (RLS)

Toutes les tables metier portent un `tenant_id` pour l'isolation multi-tenant.

| Table | Colonne | Default |
|-------|---------|---------|
| `purchase.commande` | `tenant_id TEXT NOT NULL` | `current_setting('app.tenant_id', true)` |
| `purchase.commande_ligne` | `tenant_id TEXT NOT NULL` | `current_setting('app.tenant_id', true)` |
| `purchase.reception` | `tenant_id TEXT NOT NULL` | `current_setting('app.tenant_id', true)` |
| `purchase.reception_ligne` | `tenant_id TEXT NOT NULL` | `current_setting('app.tenant_id', true)` |
| `purchase.facture_fournisseur` | `tenant_id TEXT NOT NULL` | `current_setting('app.tenant_id', true)` |

RLS active sur toutes les tables :
```sql
CREATE POLICY tenant_isolation ON purchase.commande
  USING (tenant_id = current_setting('app.tenant_id', true));
```

- En dev : `app.tenant_id = 'dev'`
- En prod : extrait du JWT
- Le tenant_id est sur chaque table (y compris lignes) car PostgREST peut query chaque table independamment

## Numerotation

- Format : `BDC-YYYY-NNN` (bons de commande)
- **Sequence chronologique sans trou** — meme regle que module quote
- Jamais modifiable apres attribution, jamais reutilisable apres suppression
- Reset au 1er janvier (NNN repart a 001)
- Helper `purchase._next_numero(p_prefix text)` : compte les existants pour l'annee en cours

## Calcul des montants

Toutes les colonnes montant sont `NUMERIC(12,2)`.

**Regle d'arrondi** — arrondi au centime **par ligne**, pas sur le total :

```sql
-- Montant HT d'une ligne
montant_ht := ROUND(quantite * prix_unitaire, 2);

-- TVA d'une ligne
montant_tva := ROUND(quantite * prix_unitaire * tva_rate / 100, 2);

-- Montant TTC d'une ligne
montant_ttc := montant_ht + montant_tva;

-- Totaux du document = somme des lignes arrondies (PAS arrondi d'une somme non arrondie)
total_ht  := SUM(ROUND(quantite * prix_unitaire, 2));
total_tva := SUM(ROUND(quantite * prix_unitaire * tva_rate / 100, 2));
total_ttc := total_ht + total_tva;
```

**JAMAIS** `ROUND(SUM(quantite * prix_unitaire * tva_rate / 100), 2)` — c'est une erreur comptable.

### TVA

Taux francais via CHECK constraint :

| Taux | Usage courant artisan |
|------|----------------------|
| 20.00% | Taux normal (fournitures, materiel) |
| 10.00% | Travaux renovation (logement > 2 ans) |
| 5.50% | Travaux amelioration energetique |
| 0.00% | Auto-entrepreneur exonere, DOM-TOM |

## Statuts (lifecycle)

**Bon de commande :** `brouillon` -> `envoye` -> `recu_partiel` -> `recu` | `annule`

Transitions strictes :
- `brouillon` -> `envoye` : validation du BDC, attribution du numero (si pas deja attribue)
- `envoye` -> `recu_partiel` : automatique a la premiere reception partielle
- `envoye` -> `recu` : automatique si toutes les lignes recues en totalite
- `recu_partiel` -> `recu` : automatique quand toutes les lignes sont completement recues
- `envoye` -> `annule` : annulation manuelle
- `brouillon` -> `annule` : annulation manuelle

RAISE EXCEPTION si :
- Transition invalide (ex: brouillon -> recu directement)
- Modification d'un document non-brouillon (header ou lignes)
- Suppression d'un document non-brouillon
- Ajout/suppression de ligne sur un document non-brouillon

### Transition automatique sur reception

La reception met a jour le statut automatiquement :
1. Enregistrer les quantites recues par ligne
2. Comparer quantite_recue cumul vs quantite commandee pour chaque ligne
3. Si toutes les lignes sont completement recues -> statut `recu`
4. Sinon -> statut `recu_partiel`

### Reception et stock

Chaque reception cree un mouvement `stock.mouvement` de type `entree` :
- Un mouvement par ligne recue
- Reference : numero BDC + numero BL
- Quantite = quantite_recue de la reception_ligne

**Statut facture fournisseur :** `recue` -> `rapprochee` -> `payee`

- `recue` : facture saisie ou importee
- `rapprochee` : liee a un BDC, montants verifies (ecart tolere < seuil configurable)
- `payee` : reglement effectue

## Rapprochement facture fournisseur

Le rapprochement consiste a :
1. Lier la facture a un BDC (`facture_fournisseur.commande_id`)
2. Comparer montant_ttc facture vs total_ttc calcule du BDC
3. Signaler les ecarts (alerte si ecart > seuil, default 0.01 EUR)
4. Valider le rapprochement (statut `rapprochee`)

Un BDC peut avoir plusieurs factures fournisseur (facturations partielles).

## Primitives pgView

| Primitive | Usage |
|-----------|-------|
| `pgv.stat()` | Dashboard KPIs (BDC en cours, en attente reception, impayees) |
| `pgv.tabs()` | Dashboard (commandes/receptions/factures) |
| `pgv.dl()` | Header BDC (fournisseur, objet, statut, dates, totaux) |
| `pgv.badge()` | Statuts : brouillon=warning, envoye=info, recu_partiel=warning, recu=success, annule=danger |
| `pgv.breadcrumb()` | Navigation (Commandes > BDC-2026-001) |
| `pgv.action()` | Boutons lifecycle (conditionnel selon statut) |
| `pgv.md_table()` | Listes paginables, lignes de commande, lignes de reception |
| `pgv.empty()` | Aucune commande/reception/facture |
| `pgv.href()` | Liens route-aware |
| `pgv.grid()` | Grille de stats |
| `pgv.card()` | Receptions sur fiche commande |
| `pgv.alert()` | Ecarts de rapprochement, alertes |

Formulaire ajout ligne inline via `<details>`. Visible **uniquement si parent brouillon**.

## Pages

| Page | Fonction | Description |
|------|----------|-------------|
| Dashboard | `get_dashboard()` | KPIs + onglets commandes recentes / receptions / factures |
| Liste commandes | `get_commandes()` | Table paginee, filtre par statut |
| Fiche commande | `get_commande(p_id)` | Header + lignes + receptions + factures liees |
| Formulaire commande | `get_commande_form(p_id DEFAULT NULL)` | NULL = creation, id = edition (brouillon only) |
| Nouvelle reception | `get_reception_form(p_commande_id)` | Formulaire avec lignes a recevoir + quantites attendues |
| Fiche reception | `get_reception(p_id)` | Detail d'une reception |
| Factures fournisseurs | `get_factures()` | Liste factures recues |
| Fiche facture | `get_facture(p_id)` | Detail + rapprochement |

## Conventions

- **UI :** French — Commande, Bon de commande, Fournisseur, Ligne, Reception, Facture fournisseur, Quantite, Prix unitaire HT, Montant HT, TVA, Total TTC, Brouillon, Envoye, Recu, Annule
- **Pages GET** : `get_*()` retournent `"text/html"`, wrappees dans `pgv.page()`
- **Actions POST** : `post_*()` prennent `p_data jsonb`, retournent `<template data-redirect>` + `<template data-toast>`
- **Navigation** : `nav_items()` retourne `TABLE(label, href, icon)`, `brand()` retourne text
- **Formulaire unifie** : `get_commande_form(p_id DEFAULT NULL)` — NULL = creation, id = edition pre-remplie
- **Upsert** : `post_commande_save` — presence d'`id` dans jsonb determine INSERT vs UPDATE (brouillon only)
- **Helpers prives** : prefixe `_` (ex: `_next_numero`, `_total_ht`, `_statut_apres_reception`) — fonctions internes, pas exposees en navigation
- **Fournisseurs** : toujours filtrer `crm.client WHERE type = 'company'` pour les selecteurs

## Relations cross-module

| Module | Relation | Contrainte |
|--------|----------|------------|
| `crm` | `purchase.commande.fournisseur_id -> crm.client(id)` | FK sans CASCADE — fournisseur non supprimable si commandes existent |
| `stock` | `purchase.commande_ligne.article_id -> stock.article(id)` | FK sans CASCADE — article non supprimable si en commande |
| `stock` | `purchase.reception` -> `stock.mouvement` | Mouvement type `entree` cree a chaque reception |

Consequence : `post_commande_delete` doit catcher l'erreur FK et afficher un message clair si applicable. Les receptions creent des mouvements stock — une reception ne peut PAS etre supprimee si le mouvement stock a ete consomme.

## File Export

- `purchase`, `purchase_ut` -> `src/`
- `purchase_qa` -> `qa/`
- **pg_pack :** `purchase,purchase_ut` (sans purchase_qa)

`_qa` dans `qa/` est normal et BY DESIGN. Ne PAS deplacer.

## Testing

```
pg_test target: "plpgsql://purchase_ut"
```

Tests critiques :
- **Arrondis** : verifier que `_total_tva` arrondit par ligne, pas sur la somme
- **Sequence** : verifier que `_next_numero` ne cree pas de trous
- **Lifecycle** : verifier chaque transition valide et invalide (brouillon -> envoye -> recu, etc.)
- **Immutabilite** : verifier que UPDATE/DELETE RAISE sur document non-brouillon
- **Reception partielle** : verifier que le statut passe a `recu_partiel` puis `recu` correctement
- **Mouvement stock** : verifier qu'une reception cree bien un mouvement `entree` dans stock
- **Rapprochement** : verifier la detection d'ecarts entre facture et BDC
- **Fournisseurs** : verifier que seuls les clients `type='company'` sont acceptes comme fournisseur

## Review UI/UX

Quand toutes les pages sont fonctionnelles, envoyer une demande de review a l'agent pgv :

```
pg_msg from:purchase to:pgv type:question subject:"Review UI/UX pages Purchase"
```

L'agent pgv lancera `diagnose('purchase', '*')` et verifiera l'ergonomie, les primitives, et les conventions.

## Gotchas

- **Depend de CRM + Stock** — DDL reference `crm.client(id)` et `stock.article(id)`, les deux doivent etre deployes avant
- **ARRONDI PAR LIGNE** — Ne JAMAIS arrondir le total directement. Toujours `SUM(ROUND(..., 2))`, jamais `ROUND(SUM(...), 2)`
- **Fournisseur = crm.client type company** — Pas de table fournisseur separee, filtrer le CRM
- **Reception partielle** — Une commande peut avoir N receptions. La quantite recue est le cumul de toutes les reception_ligne pour une commande_ligne donnee
- **Mouvement stock a la reception** — Pas a la commande. Le stock bouge uniquement quand la marchandise est physiquement recue
- **Facture fournisseur != quote.facture** — La facture fournisseur est un document recu (entrant), pas emis. Pas de numerotation interne obligatoire (on garde le numero du fournisseur)
- **Pas de PDF** — hors scope v0.1, juste donnees + pages pgView
- **Pas de reordonnancement des lignes** — supprimer et recreer
- **Totaux calcules live** — pas de cache sur le document, ok pour volumes artisan (5-20 lignes)
- **Stock module peut etre vide** — Le module stock est une dependance declaree mais peut ne pas encore avoir toutes ses tables. Prevoir une degradation gracieuse (FKs optionnelles si stock.article n'existe pas encore)
