# crm — Gestion Clients

Module CRM pour ERP artisan. Gestion des clients (particuliers + entreprises), contacts secondaires, historique des interactions.

**Dépend de :** `pgv` (primitives UI)

## Schemas

| Schema | Role | Contenu |
|--------|------|---------|
| `crm` | Core CRM + pages | Tables, helpers, pages, actions |
| `crm_ut` | pgTAP tests | test_* functions |
| `crm_qa` | QA seed data only | seed(), clean() |

## Layout

```
build/crm.ddl.sql        # Schema + 3 tables + trigger + grants
build/crm.func.sql       # pg_pack output (crm + crm_ut, dependency-sorted)
src/crm/*.sql            # Function sources (pg_func_save)
src/crm_ut/test_*.sql    # Test sources (pg_func_save)
qa/crm_qa/*.sql          # QA/demo sources (pg_func_save — _qa suffix → qa/)
```

## Data Model

| Table | Purpose | Key columns |
|-------|---------|-------------|
| `crm.client` | Clients | type (individual/company), name, email?, phone?, address?, city?, postal_code?, tier, tags text[], notes, active |
| `crm.contact` | Contacts secondaires | client_id FK CASCADE, name, role, email?, phone?, is_primary |
| `crm.interaction` | Historique | client_id FK CASCADE, type (call/visit/email/note), subject, body |

**Politique NULL** : `NOT NULL` par défaut. Seuls email, phone, address, city, postal_code sont nullable (absence = info inconnue). Les colonnes notes, body, role ont un default `''` (jamais NULL).

Trigger `trg_client_updated_at` met à jour `updated_at` automatiquement sur UPDATE.

Types d'interaction : `call`, `visit`, `email`, `note` uniquement. Pas de devis/factures — bounded context séparé à venir.

## Données personnelles (RGPD)

Ce module stocke des données personnelles (nom, email, téléphone, adresse).
- Le champ `active = false` désactive un client sans supprimer ses données
- La suppression CASCADE efface contacts + interactions du client
- **Attention** : le module `quote` référence `crm.client(id)` SANS CASCADE — un client avec devis/factures ne peut PAS être supprimé (FK constraint)

## Types de client

| Type | Usage | Particularités |
|------|-------|----------------|
| `individual` | Particulier | Nom = prénom + nom, pas de SIRET |
| `company` | Entreprise/SARL/auto-entrepreneur | Nom = raison sociale, contacts secondaires pertinents |

## Validation données

- **postal_code** : 5 chiffres (France), pas de CHECK en DB mais à valider côté fonction
- **email** : validation basique (contient @), pas de regex complexe
- **phone** : format libre (l'artisan saisit comme il veut : 06..., +33...)
- **Tags** : normalisés `lower(trim())`, pas de doublons via `array_remove` avant `array_append`

## Relations cross-module

| Module | Relation | Contrainte |
|--------|----------|------------|
| `quote` | `quote.devis.client_id → crm.client(id)` | FK sans CASCADE — client non supprimable si devis existe |
| `quote` | `quote.facture.client_id → crm.client(id)` | FK sans CASCADE — idem |

Conséquence : `post_client_delete` doit catcher l'erreur FK et afficher un message clair ("Client lié à des devis/factures, impossible de supprimer").

## Primitives pgView disponibles

| Primitive | Usage CRM |
|-----------|-----------|
| `pgv.page(title, body)` | Layout standard |
| `pgv.card(title, body)` | Interaction cards, formulaires inline |
| `pgv.dl(VARIADIC)` | Fiche client (key-value pairs) |
| `pgv.stat(label, value, variant)` | Dashboard KPIs |
| `pgv.badge(label, variant)` | Tags + tier |
| `pgv.tabs(VARIADIC)` | Onglets fiche client |
| `pgv.breadcrumb(VARIADIC)` | Fil d'Ariane (Clients > Nom) |
| `pgv.action(rpc, label, params, confirm)` | Boutons POST (supprimer, etc.) |
| `pgv.md_table(headers, rows)` | Tables triables/paginées |
| `pgv.empty(msg)` | États vides (0 interactions, 0 contacts) |
| `pgv.alert(variant, msg)` | Messages contextuels |
| `pgv.radio(name, options, selected)` | Type client (individu/entreprise) |
| `pgv.href(path)` | Liens route-aware |
| `pgv.grid(VARIADIC)` | Grille de stats |

Pas de primitive `timeline` — les interactions se rendent comme une série de `pgv.card()` triées par date DESC.

Formulaires inline via `<details><summary>Ajouter...</summary><form>...</form></details>` (pattern cad).

## Conventions

- **UI language:** French (Client, Entreprise, Particulier, Appel, Visite, Courriel, Note)
- **Tags** : normalisés `lower(trim())`, pas de doublons, stockés en text[]
- **Pages GET** : `get_*()` retournent `"text/html"`, wrappées dans `pgv.page()`
- **Actions POST** : `post_*()` prennent `p_data jsonb`, retournent `<template data-redirect>` + `<template data-toast>`
- **Navigation** : `nav_items()` retourne `TABLE(label, href, icon)`, `brand()` retourne text
- **Formulaire unifié** : `get_client_form(p_id DEFAULT NULL)` — NULL = création, id = édition pré-remplie
- **Upsert** : `post_client_save` — présence d'`id` dans jsonb détermine INSERT vs UPDATE

## File Export Convention

`pg_func_save` auto-resolves via module registry :
- `crm`, `crm_ut` → `src/` (`src/crm/*.sql`, `src/crm_ut/*.sql`)
- `crm_qa` → `qa/` (`qa/crm_qa/*.sql`)

C'est NORMAL et BY DESIGN. Ne PAS déplacer les fichiers QA de `qa/` vers `src/`.

**pg_pack :** Toujours pack `crm,crm_ut` (sans crm_qa). QA pas inclus dans les build artifacts.

## Testing

```
pg_test target: "plpgsql://crm_ut"
```

## Review UI/UX

Quand toutes les pages sont fonctionnelles, envoyer une demande de review à l'agent pgv :

```
pg_msg from:crm to:pgv type:question subject:"Review UI/UX pages CRM"
```

L'agent pgv lancera `diagnose('crm', '*')` et vérifiera l'ergonomie, les primitives, et les conventions.

## Gotchas

- **Pas de devis/factures** — `interaction.type` n'inclut PAS `quote`/`invoice`, ce sera un module séparé
- **Pas de recherche** v0.1 — `<md data-page="20">` avec tri par colonne suffit
- **Pas de `country`** — contexte 100% France pour l'instant
- **Tags dans le formulaire** : champ texte libre séparé par virgules, transformé en `string_to_array()` côté serveur
