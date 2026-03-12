# stock — Gestion des Stocks

Module de gestion des stocks pour ERP artisan. Articles (materiaux, fournitures), mouvements entrees/sorties, inventaire, multi-depots, seuils d'alerte, valorisation PMP.

**Depend de :** `pgv` (primitives UI), `crm` (fournisseurs = `crm.client` de type company)

## Schemas

| Schema | Role | Contenu |
|--------|------|---------|
| `stock` | Core stock + pages | Tables, helpers, pages, actions |
| `stock_ut` | pgTAP tests | test_* functions |
| `stock_qa` | QA seed data only | seed(), clean() |

## Layout

```
build/stock.ddl.sql        # Schema + tables + triggers + grants
build/stock.func.sql       # pg_pack output (stock + stock_ut, dependency-sorted)
src/stock/*.sql            # Function sources (pg_func_save)
src/stock_ut/test_*.sql    # Test sources (pg_func_save)
qa/stock_qa/*.sql          # QA/demo sources (pg_func_save — _qa suffix -> qa/)
```

## Data Model

| Table | Purpose | Key columns |
|-------|---------|-------------|
| `stock.article` | Articles (materiaux, fournitures) | ref UNIQUE, designation, unite, categorie, stock_min, pmp, active |
| `stock.depot` | Lieux de stockage | nom UNIQUE, adresse, notes |
| `stock.mouvement` | Mouvements de stock | article_id FK, depot_id FK, type, quantite, prix_unitaire, reference, notes |
| `stock.article_depot` | Stock par article/depot (cache) | article_id FK, depot_id FK, quantite, UNIQUE(article_id, depot_id) |

### Politique NULL

`NOT NULL` par defaut. Exceptions justifiees :
- `article.stock_min` — NULL = pas de seuil d'alerte pour cet article
- `mouvement.prix_unitaire` — NULL pour les sorties (seules les entrees ont un prix)
- `mouvement.reference` — NULL = pas de reference externe (bon de livraison, etc.)
- `depot.adresse` — NULL = adresse inconnue

Les colonnes `notes` ont un default `''` (jamais NULL).

### Articles

| Colonne | Type | Contraintes |
|---------|------|-------------|
| `id` | `UUID DEFAULT gen_random_uuid()` | PK |
| `tenant_id` | `TEXT NOT NULL` | RLS |
| `ref` | `TEXT NOT NULL` | UNIQUE (par tenant) |
| `designation` | `TEXT NOT NULL` | |
| `unite` | `TEXT NOT NULL` | CHECK (voir unites) |
| `categorie` | `TEXT NOT NULL DEFAULT ''` | |
| `stock_min` | `NUMERIC(12,2)` | Seuil alerte, nullable |
| `pmp` | `NUMERIC(12,4) NOT NULL DEFAULT 0` | Prix Moyen Pondere |
| `active` | `BOOLEAN NOT NULL DEFAULT true` | |
| `notes` | `TEXT NOT NULL DEFAULT ''` | |
| `created_at` | `TIMESTAMPTZ NOT NULL DEFAULT now()` | |
| `updated_at` | `TIMESTAMPTZ NOT NULL DEFAULT now()` | |

### Unites

| Code | Label | Usage |
|------|-------|-------|
| `u` | Unite | Pieces, quincaillerie |
| `m` | Metre lineaire | Tuyaux, cables, profiles |
| `m2` | Metre carre | Panneaux, tissus |
| `m3` | Metre cube | Beton, granulats, terre |
| `kg` | Kilogramme | Materiaux en vrac |
| `l` | Litre | Peinture, solvants, colles |

### Types de mouvement

| Type | Sens | Usage |
|------|------|-------|
| `entree` | + | Achat, reception fournisseur |
| `retour` | + | Retour de chantier |
| `sortie` | - | Consommation chantier |
| `perte` | - | Casse, peremption, vol |
| `inventaire` | +/- | Ajustement suite inventaire physique |

`entree` et `retour` ajoutent du stock (quantite positive).
`sortie` et `perte` retirent du stock (quantite positive dans la table, signe determine par le type).
`inventaire` peut aller dans les deux sens (quantite signee : positive = surplus, negative = manque).

### Depots

| Colonne | Type | Contraintes |
|---------|------|-------------|
| `id` | `UUID DEFAULT gen_random_uuid()` | PK |
| `tenant_id` | `TEXT NOT NULL` | RLS |
| `nom` | `TEXT NOT NULL` | UNIQUE (par tenant) |
| `adresse` | `TEXT` | Nullable |
| `notes` | `TEXT NOT NULL DEFAULT ''` | |
| `active` | `BOOLEAN NOT NULL DEFAULT true` | |

### Table article_depot (cache stock par depot)

Stocke la quantite en stock par couple (article, depot). Mise a jour par trigger sur `stock.mouvement`.

- `quantite` = SUM des mouvements pour ce couple (source de verite = mouvements)
- Le trigger `trg_mouvement_update_stock` met a jour `article_depot.quantite` a chaque INSERT sur `mouvement`
- Un mouvement ne peut PAS etre supprime ou modifie (INSERT only) — correction via mouvement `inventaire`

## Multi-tenant (RLS)

Toutes les tables metier portent un `tenant_id` pour l'isolation multi-tenant.

| Table | Colonne | Default |
|-------|---------|---------|
| `stock.article` | `tenant_id TEXT NOT NULL` | `current_setting('app.tenant_id', true)` |
| `stock.depot` | `tenant_id TEXT NOT NULL` | `current_setting('app.tenant_id', true)` |
| `stock.mouvement` | `tenant_id TEXT NOT NULL` | `current_setting('app.tenant_id', true)` |
| `stock.article_depot` | `tenant_id TEXT NOT NULL` | `current_setting('app.tenant_id', true)` |

RLS active sur les 4 tables :
```sql
CREATE POLICY tenant_isolation ON stock.article
  USING (tenant_id = current_setting('app.tenant_id', true));
```

- En dev : `app.tenant_id = 'dev'`
- En prod : extrait du JWT
- Le tenant_id est sur chaque table car PostgREST peut query chaque table independamment

## Valorisation PMP (Prix Moyen Pondere)

Le PMP (PUMP en anglais : Weighted Average Cost) est recalcule a chaque entree :

```sql
-- Sur chaque mouvement de type 'entree' :
nouveau_pmp := (ancien_pmp * stock_avant + quantite * prix_unitaire)
             / (stock_avant + quantite);
```

- Recalcul UNIQUEMENT sur les entrees (pas sur les retours — un retour reprend le PMP courant)
- Si stock_avant = 0, le PMP = prix_unitaire de l'entree
- Stocke dans `article.pmp` (NUMERIC(12,4) pour precision intermediaire)
- **Valeur du stock** = SUM(quantite * pmp) pour tous les articles

## Relations cross-module

| Module | Relation | Contrainte |
|--------|----------|------------|
| `crm` | Fournisseurs = `crm.client` de type `company` | Pas de FK directe — le lien fournisseur est via `mouvement.reference` (bon de livraison) ou futur champ `fournisseur_id` |

Les fournisseurs ne sont PAS une table separee — ce sont des `crm.client` avec `type = 'company'`. En v0.1, le lien fournisseur/mouvement est textuel (champ `reference`). Un champ `fournisseur_id FK crm.client(id)` pourra etre ajoute en v0.2.

## Pages pgView

| Page | Fonction | Description |
|------|----------|-------------|
| Dashboard | `get_home()` | KPIs : nb articles, valeur totale stock, nb alertes, nb depots |
| Liste articles | `get_articles()` | Tableau pagine, filtre actif/inactif, alerte stock bas |
| Fiche article | `get_article(p_id)` | Detail article + historique mouvements + stock par depot |
| Formulaire article | `get_article_form(p_id DEFAULT NULL)` | Creation / edition article |
| Liste depots | `get_depots()` | Tableau des depots avec stock total par depot |
| Fiche depot | `get_depot(p_id)` | Detail depot + articles presents |
| Formulaire depot | `get_depot_form(p_id DEFAULT NULL)` | Creation / edition depot |
| Mouvement | `get_mouvement_form(p_article_id DEFAULT NULL)` | Saisie d'un mouvement (entree/sortie/inventaire) |
| Alertes | `get_alertes()` | Articles sous le seuil stock_min |

### Actions POST

| Action | Fonction | Description |
|--------|----------|-------------|
| Sauver article | `post_article_save(p_data)` | Upsert (id present = UPDATE) |
| Supprimer article | `post_article_delete(p_data)` | Soft delete (active = false) |
| Sauver depot | `post_depot_save(p_data)` | Upsert |
| Enregistrer mouvement | `post_mouvement(p_data)` | INSERT mouvement + MAJ stock cache + recalcul PMP si entree |

## Primitives pgView

| Primitive | Usage Stock |
|-----------|-------------|
| `pgv.page(title, body)` | Layout standard |
| `pgv.stat()` | Dashboard KPIs (articles, valeur stock, alertes, depots) |
| `pgv.grid()` | Grille de stats dashboard |
| `pgv.tabs()` | Fiche article (mouvements / depots) |
| `pgv.dl()` | Fiche article (ref, designation, unite, PMP, stock) |
| `pgv.badge()` | Alertes : stock bas=danger, ok=success, inactif=warning |
| `pgv.breadcrumb()` | Navigation (Articles > REF-001) |
| `pgv.action()` | Boutons POST (supprimer, mouvement rapide) |
| `pgv.md_table()` | Listes paginables/triables |
| `pgv.empty()` | Aucun mouvement, aucun article |
| `pgv.alert()` | Alerte stock bas sur fiche article |
| `pgv.href()` | Liens route-aware |
| `pgv.card()` | Resume depot, formulaire inline |

Formulaire mouvement inline via `<details><summary>Nouveau mouvement...</summary><form>...</form></details>`.

## Conventions

- **UI :** French — Article, Depot, Mouvement, Entree, Sortie, Retour, Perte, Inventaire, Quantite, Prix unitaire, Seuil alerte, Valeur stock
- **Pages GET** : `get_*()` retournent `"text/html"`, wrappees dans `pgv.page()`
- **Actions POST** : `post_*()` prennent `p_data jsonb`, retournent `<template data-redirect>` + `<template data-toast>`
- **Navigation** : `nav_items()` retourne `TABLE(label, href, icon)`, `brand()` retourne text
- **Formulaire unifie** : `get_article_form(p_id DEFAULT NULL)` — NULL = creation, id = edition pre-remplie
- **Upsert** : `post_article_save` — presence d'`id` dans jsonb determine INSERT vs UPDATE
- **Helpers prives** : prefixe `_` (ex: `_recalc_pmp`, `_stock_total`) — fonctions internes, pas exposees en navigation
- **Mouvements INSERT only** : on ne modifie/supprime JAMAIS un mouvement. Correction = nouveau mouvement `inventaire`

## File Export

- `stock`, `stock_ut` -> `src/`
- `stock_qa` -> `qa/`
- **pg_pack :** `stock,stock_ut` (sans stock_qa)

`_qa` dans `qa/` est normal et BY DESIGN. Ne PAS deplacer.

## Testing

```
pg_test target: "plpgsql://stock_ut"
```

Tests critiques :
- **PMP** : verifier le recalcul sur entree (cas stock vide, cas stock existant, cas entrees multiples)
- **Stock cache** : verifier que `article_depot.quantite` = SUM des mouvements apres chaque operation
- **Alertes** : verifier la detection articles sous seuil (stock < stock_min)
- **Mouvements immutables** : verifier que UPDATE/DELETE RAISE sur mouvement
- **Unites** : verifier le CHECK constraint sur les unites valides
- **Multi-depot** : verifier stock independant par depot pour le meme article

## Review UI/UX

Quand toutes les pages sont fonctionnelles, envoyer une demande de review a l'agent pgv :

```
pg_msg from:stock to:pgv type:question subject:"Review UI/UX pages Stock"
```

L'agent pgv lancera `diagnose('stock', '*')` et verifiera l'ergonomie, les primitives, et les conventions.

## Gotchas

- **Depend de CRM** — Les fournisseurs sont des `crm.client(type='company')`, CRM doit etre deploye avant
- **Mouvements INSERT only** — JAMAIS de UPDATE/DELETE sur `stock.mouvement`. Correction = mouvement `inventaire`. Trigger BEFORE UPDATE/DELETE doit RAISE EXCEPTION.
- **PMP recalcule seulement sur entree** — Les retours reprennent le PMP courant, les sorties/pertes n'affectent pas le PMP
- **article_depot = cache** — La source de verite est toujours `SUM(mouvements)`. Si incoherence, recalculer depuis les mouvements.
- **Pas de stock negatif** — En v0.1, le trigger doit RAISE si une sortie donnerait un stock negatif dans le depot concerne
- **Pas de lien direct fournisseur** — En v0.1, pas de FK fournisseur_id sur mouvement. Le lien est textuel via `reference` (numero bon de livraison). FK possible en v0.2.
- **Pas de gestion de lots** — hors scope v0.1 (pas de numero de lot, pas de FIFO/LIFO, que PMP)
- **Pas de code-barres/EAN** — hors scope v0.1, le champ `ref` est une reference interne libre
- **Soft delete articles** — `active = false`, pas de suppression physique (des mouvements referent l'article)
- **Categories texte libre** — pas de table categories en v0.1, champ texte libre normalise `lower(trim())`
