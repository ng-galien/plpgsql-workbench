---
name: document-dev
description: Développement du module document (XHTML composition engine). Écrire des fonctions PL/pgSQL pour les chartes, documents, pages, patch XHTML, layout check. Se déclenche quand on travaille sur le module document, qu'on crée des fonctions PL/pgSQL pour la composition, le patch HTML, la validation charte, ou le layout check.
---

# Document Module — Developer Guide

Tu développes le moteur de composition XHTML. Le code métier vit dans PostgreSQL.

## Priorité d'implémentation

### 1. Fondations (charte + doc CRUD)
```
charte_create → charte_load → charte_list → charte_delete
doc_new → doc_load → doc_list → doc_delete → doc_duplicate
brand() → nav_items() → get_index() → i18n_seed()
```

### 2. Composition XHTML
```
html_set → html_patch → style_merge
xhtml_validate (xmlparse)
```

### 3. Validation
```
charte_check → layout_check → normalize_color
charte_tokens_to_css → context_token (pgcrypto hmac)
```

### 4. Pages pgView
```
get_chartes → get_charte → get_document
post_charte_create → post_charte_delete
post_doc_create → post_doc_delete → post_doc_duplicate
```

## Patterns techniques

### Style merge en PL/pgSQL

```sql
-- Parser "width:210mm;color:red" en paires key-value
-- Merger avec les nouveaux styles (last-write-wins par clé)
-- Resérialiser en string CSS

CREATE FUNCTION docs.style_merge(p_existing text, p_new text) RETURNS text
-- Utiliser regexp_split_to_table sur ';' puis sur ':'
-- Accumuler dans un tableau associatif via jsonb
```

### Patch XHTML par data-id

```sql
-- Localiser l'élément par data-id="xxx" dans le HTML text
-- Modifier son style/content/attributs
-- Revalider avec xmlparse() en sortie

CREATE FUNCTION docs.xhtml_patch(p_html text, p_ops jsonb) RETURNS text
-- Pour chaque op: regexp pour trouver data-id, string manipulation pour modifier
-- Le XHTML est contrôlé (on le génère) → regex fiable
```

### Layout check

```sql
-- Extraire les width:NNmm et height:NNmm des styles inline
-- Comparer aux dimensions du canvas
-- Retourner les éléments en débordement

CREATE FUNCTION docs.layout_check(p_html text, p_w numeric, p_h numeric) RETURNS text
-- regexp_matches pour extraire data-id + style
-- regexp pour parser NNmm
-- Comparer à p_w / p_h
```

### Charte compliance

```sql
-- Vérifier que les couleurs/fonts/shadows utilisent var(--charte-*)
-- Pas de hardcoded values quand une charte est active

CREATE FUNCTION docs.charte_check(p_html text, p_charte_id text) RETURNS text
-- Extraire tous les style="..." du HTML
-- Pour chaque propriété couleur (color, background-color, border-color...)
-- Vérifier que la valeur est var(--charte-*) ou transparente
-- Idem pour font-family et box-shadow
```

### Charte tokens → CSS

```sql
-- Générer le bloc CSS :root { --charte-color-bg: #FAF6F1; ... }
-- + @import Google Fonts

CREATE FUNCTION docs.charte_tokens_to_css(p_charte docs.charte) RETURNS text
-- Itérer les colonnes color_*, font_*, spacing_*, shadow_*, radius_*
-- Générer les variables CSS
-- color_extra jsonb → itérer les clés dynamiques
-- Détecter les noms Google Fonts (non-generic) → @import url(...)
```

## Tests

Chaque fonction a un test pgTAP dans `docs_ut` :

```sql
CREATE FUNCTION docs_ut.test_charte_create() RETURNS SETOF text AS $$
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  -- Créer une charte
  -- Vérifier les 6 couleurs obligatoires
  -- Vérifier le context_token
  RETURN NEXT ok(...);
END;
$$ LANGUAGE plpgsql;
```

## Rappels workflow

- `pg_func_set` pour créer/modifier
- `pg_test schema:docs_ut` pour valider
- `pg_pack schemas: document,docs_ut,docs_qa` pour exporter
- `pg_func_save target: plpgsql://docs` pour versionner
