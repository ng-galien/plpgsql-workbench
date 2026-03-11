# quote — Devis & Factures

Module de facturation pour ERP artisan français. Devis, factures, lignes de détail avec TVA, numérotation légale.

**Dépend de :** `pgv` (primitives UI), `crm` (table `crm.client`)

## Schemas

| Schema | Role |
|--------|------|
| `quote` | Core + pages |
| `quote_ut` | pgTAP tests |
| `quote_qa` | QA seed data only | seed(), clean() |

## Layout

```
build/quote.ddl.sql       # 3 tables + triggers + grants
build/quote.func.sql      # pg_pack output (quote + quote_ut)
src/quote/*.sql           # Function sources (pg_func_save)
src/quote_ut/test_*.sql   # Test sources
qa/quote_qa/*.sql         # QA/demo sources (_qa → qa/)
```

## Data Model

| Table | Purpose | Key columns |
|-------|---------|-------------|
| `quote.devis` | Devis | numero UNIQUE, client_id FK, objet, statut, notes, validite_jours |
| `quote.facture` | Factures | numero UNIQUE, client_id FK, devis_id? FK, objet, statut, notes, paid_at? |
| `quote.ligne` | Lignes de détail | devis_id? XOR facture_id?, sort_order, description, quantite, unite, prix_unitaire, tva_rate |

### Politique NULL

`NOT NULL` par défaut. Exceptions justifiées :
- `facture.devis_id` — NULL = facture directe (pas issue d'un devis)
- `facture.paid_at` — NULL = pas encore payée
- `ligne.devis_id` / `ligne.facture_id` — XOR constraint : exactement un parent

## Règles comptables françaises

### Numérotation (obligation légale)

- Format : `DEV-YYYY-NNN` (devis), `FAC-YYYY-NNN` (factures)
- **Séquence chronologique sans trou** — obligation article L441-9 Code de commerce
- Jamais modifiable après attribution, jamais réutilisable après suppression
- Reset au 1er janvier (NNN repart à 001)
- Helper `quote._next_numero(p_prefix text)` : compte les existants pour l'année en cours

### Calcul des montants

Toutes les colonnes montant sont `NUMERIC(12,2)`.

**Règle d'arrondi** — arrondi au centime **par ligne**, pas sur le total :

```sql
-- Montant HT d'une ligne
montant_ht := ROUND(quantite * prix_unitaire, 2);

-- TVA d'une ligne
montant_tva := ROUND(quantite * prix_unitaire * tva_rate / 100, 2);

-- Total TTC d'une ligne
montant_ttc := montant_ht + montant_tva;

-- Totaux du document = somme des lignes arrondies (PAS arrondi d'une somme non arrondie)
total_ht  := SUM(ROUND(quantite * prix_unitaire, 2));
total_tva := SUM(ROUND(quantite * prix_unitaire * tva_rate / 100, 2));
total_ttc := total_ht + total_tva;
```

**JAMAIS** `ROUND(SUM(quantite * prix_unitaire * tva_rate / 100), 2)` — c'est une erreur comptable.

### TVA

Taux français via CHECK constraint :

| Taux | Usage courant artisan |
|------|----------------------|
| 20.00% | Taux normal (fournitures, main d'oeuvre neuf) |
| 10.00% | Travaux rénovation (logement > 2 ans) |
| 5.50% | Travaux amélioration énergétique |
| 0.00% | Auto-entrepreneur exonéré, DOM-TOM |

### Unités

| Code | Label | Usage |
|------|-------|-------|
| `u` | Unité | Pièces, fournitures |
| `h` | Heure | Main d'oeuvre |
| `m` | Mètre linéaire | Tuyaux, câbles |
| `m2` | Mètre carré | Surfaces (peinture, carrelage) |
| `m3` | Mètre cube | Volumes (béton, terre) |
| `forfait` | Forfait | Prix global |

### Mentions obligatoires devis (article L441-1)

Le devis affiché doit inclure :
- Numéro + date
- Identité client (nom, adresse)
- Objet / description des travaux
- Détail ligne par ligne (description, quantité, unité, PU HT, taux TVA)
- Total HT, Total TVA (ventilé par taux), Total TTC
- Durée de validité (default 30 jours)
- **Conditions de paiement** : à afficher (stocké dans notes ou futur champ dédié)

### Mentions obligatoires facture (articles L441-9, R441-10)

En plus des mentions du devis :
- Date d'émission + date de la prestation/livraison
- **Conditions de règlement** : délai de paiement
- **Pénalités de retard** : mention obligatoire même si non appliquées (taux BCE x3 ou taux contractuel)
- **Indemnité forfaitaire de recouvrement** : 40 EUR (mention obligatoire)
- Référence du devis d'origine si applicable

### Immutabilité

- **Devis brouillon** : modifiable librement (lignes, header)
- **Devis envoyé** : plus modifiable. Transitions possibles : accepté ou refusé
- **Facture brouillon** : modifiable librement
- **Facture envoyée** : **JAMAIS modifiable** — obligation légale. Pas de modification, pas de suppression. Seul recours futur : avoir (pas dans v0.1)
- **Facture payée** : idem, immutable

### Affichage montants

```sql
-- Format français : espace comme séparateur milliers, virgule décimale
to_char(montant, 'FM999G999D00')  -- avec lc_monetary = 'fr_FR'
-- Ou plus simple :
to_char(montant, 'FM999 999.00') || ' EUR'

-- Variante avec symbole euro :
REPLACE(to_char(montant, 'FM999 999.00'), '.', ',') || ' €'
```

Le choix du format (point ou virgule décimale) doit être **cohérent** dans tout le module.

## Statuts (lifecycle)

**Devis :** `brouillon` → `envoye` → `accepte` | `refuse`
**Facture :** `brouillon` → `envoyee` → `payee`

Transitions strictes — RAISE EXCEPTION si :
- Transition invalide (ex: brouillon → accepte directement)
- Modification d'un document non-brouillon
- Suppression d'un document non-brouillon
- Ajout/suppression de ligne sur un document non-brouillon

Conversion devis → facture : uniquement si devis `accepte`. Copie le header + toutes les lignes. Lie `facture.devis_id`.

## Primitives pgView

| Primitive | Usage |
|-----------|-------|
| `pgv.stat()` | Dashboard KPIs (devis en cours, impayés, CA mois, taux acceptation) |
| `pgv.tabs()` | Dashboard (devis/factures récents) |
| `pgv.dl()` | Header devis/facture (client, objet, statut, dates, totaux) |
| `pgv.badge()` | Statuts : brouillon=warning, envoye/envoyee=info, accepte/payee=success, refuse=danger |
| `pgv.breadcrumb()` | Navigation (Devis > DEV-2026-001) |
| `pgv.action()` | Boutons lifecycle (conditionnel selon statut) |
| `pgv.md_table()` | Listes paginées, tableau des lignes avec totaux |
| `pgv.empty()` | Aucun devis/facture |
| `pgv.href()` | Liens route-aware |
| `pgv.grid()` | Grille de stats |

Formulaire ajout ligne inline via `<details>`. Visible **uniquement si parent brouillon**.

## Conventions

- **UI :** French — Devis, Facture, Brouillon, Envoyé, Accepté, Refusé, Payée, Ligne, Quantité, Prix unitaire HT, Montant HT, TVA, Total TTC
- **Pages GET** : `get_*()` retournent `"text/html"`, wrappées dans `pgv.page()`
- **Actions POST** : `post_*()` prennent `p_data jsonb`, retournent `<template data-redirect>` + `<template data-toast>`
- **Formulaire unifié** : `get_devis_form(p_id DEFAULT NULL)` / `get_facture_form(p_id DEFAULT NULL)`
- **Upsert** : `post_devis_save` / `post_facture_save` — présence d'`id` dans jsonb = UPDATE (brouillon only)
- **Helpers privés** : préfixe `_` (ex: `_next_numero`, `_total_ht`) — fonctions internes, pas exposées en navigation

## File Export

- `quote`, `quote_ut` → `src/`
- `quote_qa` → `qa/`
- **pg_pack :** `quote,quote_ut` (sans quote_qa)

`_qa` dans `qa/` est normal et BY DESIGN. Ne PAS déplacer.

## Testing

```
pg_test target: "plpgsql://quote_ut"
```

Tests critiques compta :
- **Arrondis** : vérifier que `_total_tva` arrondit par ligne, pas sur la somme
- **Séquence** : vérifier que `_next_numero` ne crée pas de trous
- **Immutabilité** : vérifier que UPDATE/DELETE RAISE sur document non-brouillon
- **Lifecycle** : vérifier chaque transition valide et invalide

## Review UI/UX

Quand toutes les pages sont fonctionnelles, envoyer une demande de review à l'agent pgv :

```
pg_msg from:quote to:pgv type:question subject:"Review UI/UX pages Quote"
```

L'agent pgv lancera `diagnose('quote', '*')` et vérifiera l'ergonomie, les primitives, et les conventions.

## Gotchas

- **Dépend de CRM** — DDL référence `crm.client(id)`, CRM doit être déployé avant
- **ARRONDI PAR LIGNE** — Ne JAMAIS arrondir le total directement. Toujours `SUM(ROUND(..., 2))`, jamais `ROUND(SUM(...), 2)`
- **Facture envoyée = immutable** — Obligation légale. Aucune modification, aucune suppression. L'avoir viendra dans une version future.
- **Numérotation sans trou** — Si un brouillon est supprimé, son numéro ne doit PAS être réattribué. Mais attention : en v0.1, le numéro est attribué à la création. Supprimer un brouillon crée un trou. Solution propre future : attribuer le numéro au moment de l'envoi, pas à la création.
- **Pas de PDF** — hors scope v0.1, juste données + pages pgView
- **Pas de réordonnancement des lignes** — supprimer et recréer
- **Totaux calculés live** — pas de cache sur le document, ok pour volumes artisan (5-20 lignes)
- **TVA ventilée** — Sur le document final, la TVA doit être affichée ventilée par taux (ex: TVA 20% = X EUR, TVA 10% = Y EUR). Pas juste un total TVA global.
