# catalog — Catalogue Produits/Services

Module catalogue pour artisans : articles, prestations, tarifs, catégories, unités de mesure.

**Dépend de :** pgv (framework UI)

**Consommé par :** quote (lignes devis/facture), stock (articles), purchase (lignes commande)

**Schemas :** `catalog` (public), `catalog_ut` (tests), `catalog_qa` (seed data)

## Modèle de données

- `catalog.categorie` — catégories arborescentes (parent_id)
- `catalog.unite` — unités de mesure (m, m2, kg, h, u, forfait...)
- `catalog.article` — produits/services avec référence, désignation, prix vente/achat HT, TVA, unité, catégorie

## Pages attendues

- `get_index()` — dashboard : stats (nb articles, catégories), recherche, liste articles avec filtres
- `get_article(p_id)` — fiche article : détail, modifier, historique prix si disponible
- `get_categories()` — gestion catégories arborescentes
- `get_article_form(p_params jsonb)` — formulaire création/édition article
- `post_article_creer(p_params jsonb)` — créer un article
- `post_article_modifier(p_params jsonb)` — modifier un article
- `post_categorie_creer(p_params jsonb)` — créer une catégorie

## Convention routeur

**IMPORTANT :** `pgv.route()` supporte max 1 argument par fonction. Utiliser `jsonb` pour les fonctions avec filtres/paramètres multiples :
```sql
CREATE FUNCTION catalog.get_index(p_params jsonb DEFAULT '{}'::jsonb) RETURNS text
-- p_params->>'q' pour recherche, p_params->>'categorie_id' pour filtre
```

## Intégration cross-module

Les autres modules appellent catalog via EXECUTE dynamique (pas de hard dependency) :
```sql
-- Exemple dans quote ou purchase
IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'catalog') THEN
  EXECUTE 'SELECT catalog.article_options()' INTO v_options;
END IF;
```

## Workflow dev (STRICT)

1. DDL → Write dans `build/catalog.ddl.sql` → `pg_schema` pour appliquer
2. Fonctions → `pg_func_set` pour créer/modifier + `pg_test` pour valider
3. Exporter → `pg_pack` (→ `build/catalog.func.sql`) + `pg_func_save` (→ `src/`)
4. `pg_query` → SELECT/DML uniquement, JAMAIS de DDL ou CREATE FUNCTION
5. JAMAIS écrire de fonctions dans des fichiers SQL

## Conventions pgView

- Tables via `<md>` blocks, JAMAIS `<table>` HTML
- CSS classes `pgv-*`, JAMAIS `style="..."`
- Primitives : `pgv.stat()`, `pgv.badge()`, `pgv.card()`, `pgv.grid()`, `pgv.empty()`, `pgv.action()`
- POST retourne raw HTML (toast/redirect), jamais wrappé dans `page()`

## Communication inter-modules

- `pg_msg_inbox module:catalog` → lire les messages entrants
- `pg_msg` → envoyer un message à un autre module
