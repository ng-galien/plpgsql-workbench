# ledger — Comptabilité en Partie Double

Comptabilité simplifiée pour artisan français. Plan comptable (PCG), écritures journal, grand livre, déclaration TVA, bilan P&L.

**Dépend de :** `pgv` (primitives UI), `quote` (lecture factures pour écritures de vente)

## Schemas

| Schema | Role |
|--------|------|
| `ledger` | Core comptabilité + pages |
| `ledger_ut` | pgTAP tests |
| `ledger_qa` | QA seed data only | seed(), clean() |

## Layout

```
build/ledger.ddl.sql      # 3 tables + triggers + plan comptable seed + grants
build/ledger.func.sql     # pg_pack output (ledger + ledger_ut)
src/ledger/*.sql          # Function sources (pg_func_save)
src/ledger_ut/test_*.sql  # Test sources
qa/ledger_qa/*.sql        # QA/demo sources (_qa → qa/)
```

## Data Model

### Comptabilité en partie double

Chaque écriture a **au moins 2 lignes**. Total débit = Total crédit. Toujours.

| Table | Purpose | Key columns |
|-------|---------|-------------|
| `ledger.account` | Plan comptable (PCG simplifié) | code UNIQUE, label, type (asset/liability/equity/revenue/expense), parent_code?, active |
| `ledger.journal_entry` | Écriture comptable | entry_date, reference, description, posted, posted_at? |
| `ledger.entry_line` | Lignes débit/crédit | journal_entry_id FK CASCADE, account_id FK, debit NUMERIC(12,2), credit NUMERIC(12,2), label |

### Politique NULL

`NOT NULL` par défaut. Exceptions justifiées :
- `account.parent_code` — NULL = compte racine (pas de parent)
- `journal_entry.posted_at` — NULL = pas encore validée

### Contraintes

- `entry_line`: `debit >= 0 AND credit >= 0 AND (debit > 0 OR credit > 0)` — une ligne est soit débit soit crédit, jamais les deux, jamais zéro
- Équilibre vérifié applicativement : `SUM(debit) = SUM(credit)` par écriture — trigger/helper avant validation

## Règles comptables

### Partie double (principe fondamental)

```
Débit (emploi) = Crédit (ressource)
```

Pour chaque transaction, **au moins 2 lignes** qui s'équilibrent :

```sql
-- Exemple : achat matériaux 100€ HT + TVA 20€, payé par banque
-- Ligne 1 : 601 Achats matériaux    débit=100.00  crédit=0
-- Ligne 2 : 4456 TVA déductible     débit=20.00   crédit=0
-- Ligne 3 : 512 Banque              débit=0        crédit=120.00
-- Total débit = 120.00 = Total crédit ✓
```

### Sens des comptes (convention PCG)

| Type | Solde normal | Calcul solde |
|------|-------------|--------------|
| `asset` (actif) | Débiteur | SUM(debit) - SUM(credit) |
| `expense` (charge) | Débiteur | SUM(debit) - SUM(credit) |
| `liability` (passif) | Créditeur | SUM(credit) - SUM(debit) |
| `equity` (capitaux) | Créditeur | SUM(credit) - SUM(debit) |
| `revenue` (produit) | Créditeur | SUM(credit) - SUM(debit) |

**JAMAIS** calculer un solde sans tenir compte du sens. Un solde négatif = anomalie à signaler.

### Plan comptable artisan (PCG simplifié, pré-seedé en DDL)

| Code | Label | Type |
|------|-------|------|
| 108 | Compte de l'exploitant | equity |
| 120 | Résultat de l'exercice | equity |
| 2154 | Outillage industriel | asset |
| 2182 | Matériel de transport | asset |
| 401 | Fournisseurs | liability |
| 411 | Clients | asset |
| 4456 | TVA déductible | asset |
| 4457 | TVA collectée | liability |
| 512 | Banque | asset |
| 530 | Caisse | asset |
| 601 | Achats matériaux | expense |
| 602 | Achats fournitures | expense |
| 604 | Sous-traitance | expense |
| 606 | Assurances | expense |
| 613 | Loyer | expense |
| 616 | Télécom | expense |
| 625 | Déplacements | expense |
| 626 | Frais postaux | expense |
| 627 | Services bancaires | expense |
| 6354 | Taxe véhicule | expense |
| 6411 | Salaires | expense |
| 706 | Prestations de services | revenue |
| 707 | Ventes de marchandises | revenue |

L'artisan peut ajouter des comptes via l'UI. Les comptes système ne sont pas supprimables.

### TVA

Deux comptes TVA :
- **4456 TVA déductible** — TVA sur achats (actif, solde débiteur)
- **4457 TVA collectée** — TVA sur ventes (passif, solde créditeur)

Déclaration TVA = solde 4457 - solde 4456. Si positif = TVA à reverser. Si négatif = crédit de TVA.

### Immutabilité

- **Écriture brouillon** (`posted = false`) : modifiable, supprimable
- **Écriture validée** (`posted = true`) : **IMMUTABLE** — trigger bloque UPDATE et DELETE
- **Correction** : passer une écriture d'extourne (contra entry) — même montants, sens inversé
- **Lignes** d'une écriture validée : trigger bloque INSERT/UPDATE/DELETE

### Exercice fiscal

Année civile (1er janvier — 31 décembre). Pas de table `fiscal_year` en v0.1 — dérivé de `entry_date`.

### Montants

`NUMERIC(12,2)` partout. Arrondi au centime par ligne (cohérent avec module `quote`).

### Lien avec module quote

`post_from_facture(facture_id)` crée automatiquement une écriture de vente :
- 411 Clients — débit = TTC
- 4457 TVA collectée — crédit = TVA
- 706/707 Produits — crédit = HT

Et lors du paiement :
- 512 Banque — débit = TTC
- 411 Clients — crédit = TTC

**Lecture seule** sur `quote.facture` et `quote.ligne` — le module ledger ne modifie JAMAIS les données quote.

## Primitives pgView

| Primitive | Usage |
|-----------|-------|
| `pgv.stat()` | Dashboard KPIs (solde banque, CA période, charges, résultat) |
| `pgv.tabs()` | Dashboard (écritures récentes / comptes) |
| `pgv.dl()` | Fiche écriture (date, référence, description, statut) |
| `pgv.badge()` | Statuts : brouillon=warning, validee=success |
| `pgv.breadcrumb()` | Navigation (Écritures > REF-001) |
| `pgv.action()` | Boutons lifecycle (valider, supprimer — conditionnel selon posted) |
| `pgv.md_table()` | Grand livre, journal, plan comptable, lignes écriture |
| `pgv.empty()` | Aucune écriture, aucune ligne |
| `pgv.href()` | Liens route-aware |
| `pgv.grid()` | Grille de stats dashboard |
| `pgv.alert()` | Écriture déséquilibrée, solde négatif |

Formulaire ajout ligne inline via `<details>`. Visible **uniquement si écriture brouillon**.

## Conventions

- **UI :** French — Écriture, Grand Livre, Plan Comptable, Débit, Crédit, Solde, Brouillon, Validée, Extourne
- **Pages GET** : `get_*()` retournent `"text/html"`, wrappées dans `pgv.page()`
- **Actions POST** : `post_*()` prennent `p_data jsonb`, retournent `<template data-redirect>` + `<template data-toast>`
- **Navigation** : `nav_items()` retourne `TABLE(label, href, icon)`, `brand()` retourne text
- **Formulaire écriture** : `get_entry_form(p_id DEFAULT NULL)` — NULL = création, id = édition pré-remplie
- **Helpers privés** : préfixe `_` (ex: `_account_balance`, `_entry_balanced`) — fonctions internes
- **Montants** : affichés avec `to_char(montant, 'FM999 999.00')` + ' €' — cohérent avec module quote

## File Export

- `ledger`, `ledger_ut` → `src/`
- `ledger_qa` → `qa/`
- **pg_pack :** `ledger,ledger_ut` (sans ledger_qa)

`_qa` dans `qa/` est normal et BY DESIGN. Ne PAS déplacer.

## Testing

```
pg_test target: "plpgsql://ledger_ut"
```

Tests critiques comptabilité :
- **Équilibre** : vérifier que validation RAISE si SUM(debit) ≠ SUM(credit)
- **Immutabilité** : UPDATE/DELETE RAISE sur écriture validée ET sur ses lignes
- **Soldes** : _account_balance retourne le bon sens selon type
- **TVA** : déclaration = 4457 - 4456, signe correct
- **Extourne** : écriture inverse annule bien le solde
- **From facture** : écriture générée depuis facture = correctement ventilée

## Review UI/UX

Quand toutes les pages sont fonctionnelles, envoyer une demande de review à l'agent pgv :

```
pg_msg from:ledger to:pgv type:question subject:"Review UI/UX pages Ledger"
```

L'agent pgv lancera `diagnose('ledger', '*')` et vérifiera l'ergonomie, les primitives, et les conventions.

## Gotchas

- **Dépend de quote** — Lecture seule sur `quote.facture` + `quote.ligne`. Quote + CRM doivent être déployés avant.
- **ÉQUILIBRE OBLIGATOIRE** — Ne JAMAIS valider une écriture déséquilibrée. `_entry_balanced()` DOIT être appelé avant `posted = true`.
- **Écriture validée = immutable** — Trigger `_protect_posted` + `_protect_posted_lines`. Seul recours = extourne.
- **Sens des comptes** — Actif/Charge = débiteur (debit-credit), Passif/Capitaux/Produit = créditeur (credit-debit). Se tromper de sens = bilan faux.
- **Plan comptable seedé** — 23 comptes insérés par DDL. Si re-run `pg_schema`, les INSERT échouent (UNIQUE). Utiliser `INSERT ... ON CONFLICT DO NOTHING` si besoin de re-seed.
- **Pas de lettrage** — Hors scope v0.1. Le rapprochement clients (411) et fournisseurs (401) est manuel.
- **Pas de clôture d'exercice** — Hors scope v0.1. Le solde des comptes 6xx/7xx n'est pas reporté automatiquement au 120 en fin d'année.
- **TVA sur encaissements vs débits** — v0.1 = TVA sur débits (le plus simple). TVA sur encaissements = futur.
