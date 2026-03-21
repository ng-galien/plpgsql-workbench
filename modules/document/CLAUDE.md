# document — XHTML Composition Engine

Moteur de composition de documents visuels en XHTML. Chartes graphiques (design tokens), documents multi-pages, validation charte, layout check. Backend du produit standalone **Maket**.

**Dépend de :** `pgv`, `asset`

**Schemas :** `document`, `document_ut` (tests), `document_qa` (seed data)

## Domaine

### Charte graphique

Système de design tokens pour garantir la cohérence visuelle. Une charte = une identité de marque.

**Socle couleur obligatoire (6 tokens) :**

| Token | Rôle | Proportion |
|-------|------|------------|
| `color_bg` | Fond de page | ~60% |
| `color_main` | Titres, éléments forts | ~30% |
| `color_accent` | CTA, highlights | ~10% |
| `color_text` | Corps de texte | — |
| `color_text_light` | Texte secondaire | — |
| `color_border` | Lignes, séparateurs | — |

Plus des tokens libres dans `color_extra` jsonb (ex: `{"ocean": "#2E7D9B", "olive": "#5C6B3C"}`).

**Font :** `font_heading` + `font_body` (Google Fonts, obligatoires).

**Spacing :** `spacing_page`, `spacing_section`, `spacing_gap`, `spacing_card` (valeurs CSS, ex: `"12mm"`).

**Shadow / Radius :** `shadow_card`, `shadow_elevated`, `radius_card` (valeurs CSS).

**Voice :** personnalité (text[]), formalité, do/dont (text[]), vocabulaire, exemples (jsonb).

**Rules :** contraintes design libres (jsonb) — ce qu'on ne doit PAS faire avec la charte.

**Révisions :** chaque modification des tokens crée un snapshot dans `charte_revision`.

### Document

Document XHTML multi-pages avec canvas (format, dimensions, fond).

**Canvas :** format (`A4`, `A3`, `A5`, `HD`, `MACBOOK`, `IPAD`, `MOBILE`, `CUSTOM`), orientation, dimensions (mm pour print, px pour screen), fond, marge texte.

**Pages :** chaque page a son HTML et un override optionnel du canvas (format différent par page). Les pages sont indexées (`page_index`).

**Charte liée :** un document référence optionnellement une charte. Toute mutation HTML est validée contre la charte (couleurs, fonts, shadows doivent utiliser `var(--charte-*)`).

**Status :** `draft` → `generated` → `signed` → `archived`.

**Ref externe :** `ref_module` + `ref_id` pour lier un document à un devis, une facture, un projet.

### XHTML

Le contenu des pages est du **XHTML strict** (XML bien formé). Conventions :

- Chaque élément visuel a un `data-id` unique
- Les styles sont **inline** (`style="..."`) car le document est autonome (pas de CSS externe)
- Les couleurs/fonts/shadows utilisent `var(--charte-*)` quand une charte est active
- Les dimensions sont en `mm` pour le print, en `px` pour le screen
- Le XHTML est validé par `xmlparse()` à chaque mutation — malformé = rejeté

### Assets

Les images sont gérées par le module transversal `asset`. Supabase Storage + Image Transformations pour le resize à la volée. Le document référence les assets par chemin relatif (`/assets/photo.jpg`).

## Tables

```
document.charte           — design tokens, voice, rules (6 couleurs NOT NULL)
document.charte_revision  — snapshot tokens par version
document.company          — émetteur (entreprise, pour factures/devis)
document.document         — document XHTML (canvas, meta, charte ref, status)
document.page             — pages XHTML (html, canvas override optionnel)
document.page_revision    — historique HTML par page
document.session          — UNLOGGED workspace (docs ouverts, zoom, pan, pending)
```

## Fonctions à implémenter

### Charte
- `charte_create(...)` — INSERT avec validation socle obligatoire
- `charte_load(name)` — tokens formatés en CSS variables + context_token
- `charte_list()` — liste avec preview tokens
- `charte_delete(name)` — DELETE
- `charte_update_tokens(id, tokens)` — UPDATE + snapshot révision
- `charte_tokens_to_css(charte)` — génère `:root { --charte-*: value }` + Google Fonts @import

### Document
- `doc_new(name, canvas, charte_id, html)` — CREATE document + première page
- `doc_load(id)` — document + pages + charte CSS
- `doc_list()` — catalogue groupé par catégorie
- `doc_delete(id)` — CASCADE pages + révisions
- `doc_duplicate(source_id, new_name)` — deep clone
- `doc_update(id, args)` — compound (rename, charte change, meta, add/remove page)

### HTML / XHTML
- `html_set(doc_id, page_index, html)` — remplacer le HTML, valider charte + layout
- `html_patch(doc_id, page_index, ops)` — patch chirurgical par data-id (style, content, insert, remove)
- `style_merge(existing, new_styles)` — merge CSS inline (key-value, last-write-wins)
- `layout_check(html, width, height)` — détecte les éléments qui dépassent le canvas
- `charte_check(html, charte_id)` — valide les couleurs/fonts/shadows contre les tokens
- `normalize_color(raw)` — normalise hex/rgb en #rrggbb pour comparaison
- `xhtml_validate(html)` — vérifie que le HTML est du XML bien formé

### Session
- `session_sync(...)` — upsert workspace state
- `session_get(user_id)` — lire l'état workspace

### pgView pages
- `get_index()` — dashboard documents
- `get_document(p_id)` — vue document avec pages
- `get_chartes()` — liste des chartes
- `get_charte(p_id)` — détail charte
- `nav_items()`, `brand()`, `i18n_seed()`

## Convention context_token

Mécanisme anti-triche : Claude doit lire une charte (`charte_load`) avant de modifier un document qui l'utilise. Le token est un HMAC des tokens de la charte (via `pgcrypto`). Si la charte change, le token expire.

```sql
-- Génération
encode(hmac('charte:' || name || '|' || tokens_hash, secret, 'sha256'), 'hex')

-- Validation
Le context_token passé par Claude est comparé au token recalculé.
```

## Lien avec Maket (standalone)

Ce module EST le backend de Maket. Le produit standalone est un packaging MCP qui se connecte au même Supabase. Les 4 verbes MCP (`get`, `set`, `patch`, `delete`) routent vers les fonctions PL/pgSQL de ce module.

```
Maket standalone → Supabase → document.* functions
Workbench ERP    → PostgREST → document.* functions (pgView pages)
```

---

## Framework pgView

Ce module est un **module indépendant** du framework pgView. Ses dépendances sont déclarées dans `module.json`.

### Conventions PL/pgSQL

- `get_*()` → pages GET, `post_*()` → actions POST. Nommage = routing automatique via `pgv.route()`
- `nav_items() -> jsonb` → menu du module. Retourne `jsonb` (JAMAIS TABLE)
- `brand() -> text` → nom affiché dans la nav
- `get_index()` → page d'accueil du module (obligatoire)
- Paramètres via query string : `/page?p_id=42` → `get_page(p_id text)`
- POST retourne raw HTML (templates `<template data-toast>` ou `<template data-redirect>`) — jamais wrappé dans `page()`
- Tables via `<md>` blocks (markdown), JAMAIS `<table>` HTML. `<md data-page="20">` pour pagination
- CSS classes `pgv-*`, JAMAIS de `style="..."` inline dans les pages pgView
- Primitives UI : `pgv.stat()`, `pgv.badge()`, `pgv.card()`, `pgv.grid()`, `pgv.empty()`, `pgv.md_table()`, `pgv.action()`

### Workflow dev (STRICT)

1. **DDL** → Write dans `build/{schema}.ddl.sql` → `pg_schema` pour appliquer
2. **Fonctions** → `pg_func_set` pour créer/modifier + `pg_test` pour valider
3. **Exporter** → `pg_pack` (→ `build/{schema}.func.sql`) + `pg_func_save` (→ `src/`)
4. `pg_query` → SELECT/DML uniquement, JAMAIS de DDL ou CREATE FUNCTION
5. JAMAIS écrire de fonctions dans des fichiers SQL — le workbench EST l'outil de dev
6. JAMAIS éditer `build/*.func.sql` — généré par `pg_pack`

### Module structure

- `module.json` → manifest (schemas, dependencies, extensions, sql, grants)
- `build/` → artefacts de déploiement (DDL + fonctions packées)
- `src/` → sources individuelles versionnées (pg_func_save)
- `_ut` schemas → tests pgTAP (`test_*()`)
- `_qa` schemas → seed data uniquement (`seed()`, `clean()`), PAS de pages

### Contenu du DDL (`build/{schema}.ddl.sql`) — STRICT

Le DDL contient **uniquement de la structure**. Ordre d'application :
```
1. Extensions     → migration globale, PAS dans le DDL module
2. DDL            → CREATE SCHEMA, CREATE TABLE, indexes, constraints, RLS
3. Functions      → pg_pack génère build/{schema}.func.sql (+ triggers)
4. Grants         → pg_pack les ajoute à la fin de chaque .func.sql
5. Seed référentiel → données de référence dans build/{schema}.seed.sql
```

### Communication inter-modules

- `pg_msg_inbox module:document` → lire les messages entrants
- `pg_msg` → envoyer un message à un autre module

## i18n

- `document.i18n_seed()` — INSERT INTO pgv.i18n(lang, key, value) les traductions FR
- Clés namespaced : `document.nav_xxx`, `document.title_xxx`, `document.btn_xxx`
- `ON CONFLICT DO NOTHING`

## Workflow agent

1. Au démarrage : **lire `pg_msg_inbox module:document`**
2. Traiter les messages par priorité (HIGH d'abord)
3. Après chaque tâche : `pg_pack schemas: document,document_ut,document_qa`
4. Puis `pg_func_save target: plpgsql://document` + `plpgsql://document_ut` + `plpgsql://document_qa`

## Gotchas

- **tenant_id** : toujours `PERFORM set_config('app.tenant_id', 'test', true)` au début de chaque test
- **XHTML strict** : `xmlparse(DOCUMENT html)` rejette le HTML malformé — toujours valider à l'entrée
- **Style inline** : les pages XHTML utilisent `style="..."` (c'est le contenu du document, pas les pages pgView)
- **pgcrypto** : nécessaire pour le context_token (HMAC) — vérifier que l'extension est chargée
