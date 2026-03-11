# FRONTEND.md — pgView + Alpine.js Reference

> Stack UI/UX pour les applications pgView.
> Ce document est la reference pour tout developpement frontend sur la plateforme.

## Stack

```
Alpine.js 3     (16 KB, CDN)      State reactif, event delegation, x-data / x-bind
PicoCSS 2       (10 KB, CDN)      Style classless, responsive, dark mode
marked.js       (8 KB, CDN)       Markdown -> HTML (tables)
panzoom         (9 KB, CDN)       Pan/zoom sur SVG/canvas (optionnel)
PostgREST 12+   (transport)       HTTP <-> PL/pgSQL, zero code serveur
PL/pgSQL        (runtime)         Genere le HTML, routing, logique metier
```

**Zero build, zero npm, zero framework JS.** Le shell HTML est un fichier statique (~150 lignes JS).

## Architecture

```
+--------------------------------------------------------------+
|  Browser : index.html + Alpine.js (shell SPA)                 |
+--------------------------------------------------------------+
|  PostgREST  ->  POST /rpc/route  {schema, path, method, params}|
|                 Content-Type: text/html (domain trick)         |
+--------------------------------------------------------------+
|  pgv.route(schema, path, method, params) -> "text/html"       |
|    -> introspect pg_proc -> dispatch get_*/post_*              |
|    -> GET: wrap in pgv.page() layout                          |
|    -> POST: return raw (toast/redirect templates)             |
+--------------------------------------------------------------+
|  pgv.* -> primitives UI composables                            |
|  {schema}.get_*() -> pages (GET)                               |
|  {schema}.post_*() -> actions (POST)                           |
+--------------------------------------------------------------+
|  PostgreSQL : tables + contraintes + RLS                       |
+--------------------------------------------------------------+
```

## 1. Le Domain `text/html`

PostgREST retourne du JSON par defaut. Pour retourner du HTML brut, un domain PostgreSQL :

```sql
CREATE DOMAIN "text/html" AS TEXT;
```

Toute fonction retournant `"text/html"` envoie directement du HTML au navigateur. Le routeur `pgv.route()` retourne ce type.

## 2. Shell HTML (Alpine.js)

Le shell est le seul fichier cote client. Il definit un composant Alpine `pgview` qui gere :

- **Navigation SPA** — `go(path)` via `fetch()` + `history.pushState()`
- **Actions POST** — `post(endpoint, data)` via `fetch()` avec `Content-Profile` header
- **Rendu** — `_render(html)` parse les templates `data-toast` et `data-redirect`
- **Enhancement** — `_enhance(el)` convertit `<md>`, tables triables/paginables, rows cliquables
- **Toast** — notifications temporaires (success/error)
- **Dialog** — dialog modale reusable (folder picker, etc.)
- **Theme** — toggle light/dark, persiste en localStorage

### Structure du shell

```html
<!DOCTYPE html>
<html lang="fr" data-theme="light">
<head>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css">
  <link rel="stylesheet" href="/pgview.css">
  <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3/dist/cdn.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
</head>
<body x-data="pgview" x-init="boot()">
  <div id="app">...</div>
  <div id="toast" role="alert" x-show="toast.show" x-transition>...</div>
  <dialog x-ref="dialog">...</dialog>
  <script>
    document.addEventListener('alpine:init', function() {
      Alpine.data('pgview', function() { return { /* ... */ }; });
    });
  </script>
</body>
</html>
```

### Deux modes de fonctionnement

Le shell detecte le mode au boot :

| Mode | Detection | Route URL | RPC endpoint |
|------|-----------|-----------|--------------|
| **App** | `<meta name="pgv-schema" content="cad">` | `/path` | `/rpc/page` |
| **Dev** | pas de meta tag | `/{schema}/path` | `/rpc/route` |

**App mode** — un seul schema fixe, URLs simples (`/`, `/drawings`, `/settings`).
**Dev mode** — multi-schema, URLs prefixees (`/pgv_qa/`, `/cad/drawings`).

## 3. Routing — pgv.route()

### Signature

```sql
pgv.route(p_schema text, p_path text, p_method text DEFAULT 'GET', p_params jsonb DEFAULT '{}')
RETURNS "text/html"
```

### Convention get_/post_

Le routeur derive le nom de fonction depuis la methode + le path :

```
GET  /             -> get_index()
GET  /drawings     -> get_drawings()
GET  /settings     -> get_settings()
POST /settings     -> post_settings()
GET  /drawing      -> get_drawing(p_params)   -- avec ?id=42
POST /save         -> post_save(p_params)
```

Les fonctions `get_*` retournent du HTML (body d'une page). Le routeur les emballe dans `pgv.page()` (nav + layout + titre).

Les fonctions `post_*` retournent des templates `data-toast` / `data-redirect`. Le routeur retourne le HTML brut sans layout.

### Dispatch par introspection pg_proc

Le routeur inspecte la signature de la fonction cible (max 1 argument) :

| Signature | Dispatch |
|-----------|----------|
| `f()` — 0 args | Appel direct |
| `f(p jsonb)` | Passe `p_params` tel quel |
| `f(p_id integer)` | Cast `p_params->>'p_id'` en integer |
| `f(p_id bigint)` | Cast `p_params->>'p_id'` en bigint |
| `f(p_id text)` | Extract `p_params->>'p_id'` |
| `f(p_id uuid)` | Cast `p_params->>'p_id'` en uuid |
| `f(p composite_type)` | `jsonb_populate_record(NULL::type, p_params)` |

Cela permet des fonctions typees sans passer du jsonb partout :

```sql
-- Fonction avec parametre scalaire
CREATE FUNCTION cad.get_drawing(p_id integer) RETURNS text ...
-- Appelee via GET /cad/drawing?id=42

-- Fonction avec type composite
CREATE TYPE cad.t_shape_input AS (drawing_id int, shape_type text, geometry jsonb);
CREATE FUNCTION cad.post_add_shape(p cad.t_shape_input) RETURNS text ...
-- Le routeur deserialise p_params en t_shape_input automatiquement
```

### GET vs POST — reponses

| Methode | Layout | Usage |
|---------|--------|-------|
| GET | `pgv.page()` wrapping (nav + titre + body) | Pages, navigation |
| POST | Raw HTML (pas de layout) | Actions, retour toast/redirect |

### Erreurs

| Cas | GET | POST |
|-----|-----|------|
| 404 (fonction introuvable) | Page 404 avec layout | `<template data-toast="error">...` |
| Erreur metier (RAISE) | Page erreur avec layout | `<template data-toast="error">...` |
| Erreur interne | Page erreur 500 | `<template data-toast="error">Erreur interne` |

## 4. data-* Contract

PL/pgSQL genere du HTML pur avec des attributs `data-*`. Le shell les interprete.

| Pattern | Qui genere | Action du shell |
|---------|-----------|-----------------|
| `<a href="/path">` | PL/pgSQL | `go(path)` navigation SPA |
| `<form data-rpc="fn">` | PL/pgSQL | `post(fn, formData)` |
| `<button data-rpc="fn" data-params='{}'>` | `pgv.action()` | `post(fn, params)` |
| `<button data-rpc="fn" data-confirm="msg">` | `pgv.action()` | Confirm + `post(fn, params)` |
| `<template data-toast="success\|error">msg` | retour POST | Toast notification |
| `<template data-redirect="/path">` | retour POST | `go(path)` redirect |
| `<button data-toggle-theme>` | `pgv.nav()` | Flip light/dark theme |
| `<button data-dialog="name" data-src="url" data-target="id">` | PL/pgSQL | Open dialog |

### Liens internes

Tous les clics sur `<a href="/...">` dans `#app` sont interceptes par le shell. Pas besoin d'attributs speciaux :

```sql
-- Genere par PL/pgSQL :
format('<a href="%s">%s</a>', pgv.href('/drawing?id=' || r.id), pgv.esc(r.name))
```

Le shell appelle `go(href)` qui fait un fetch vers `/rpc/route`.

### Formulaires

```sql
-- Formulaire htmx-style avec data-rpc
RETURN '<form data-rpc="page">'
  || '<input type="hidden" name="p_path" value="/settings">'
  || '<input type="hidden" name="p_method" value="POST">'
  || '<label>Nom<input name="name" value="' || pgv.esc(v_name) || '"></label>'
  || '<button type="submit">Enregistrer</button>'
  || '</form>';
```

Le shell intercepte le `submit`, collecte les champs via `FormData`, et appelle `post(rpc, data)`.

### Actions (boutons POST)

```sql
-- Genere par pgv.action() :
pgv.action('page', 'Supprimer', 'danger',
  '{"p_path": "/delete", "p_method": "POST", "id": "42"}',
  'Confirmer la suppression ?')
-- -> <button data-rpc="page" data-params='{"p_path":...}' data-confirm="...">Supprimer</button>
```

### Reponses POST

Les fonctions `post_*` retournent des templates pour piloter le shell :

```sql
-- Toast de succes
RETURN '<template data-toast="success">Document enregistre</template>';

-- Toast + redirect
RETURN '<template data-toast="success">Cree avec succes</template>'
    || '<template data-redirect="/drawings"></template>';

-- Toast d'erreur (via RAISE dans le routeur)
RAISE EXCEPTION 'Nom obligatoire' USING HINT = 'Remplir le champ nom';
-- Le routeur attrape et retourne: <template data-toast="error">Nom obligatoire</template>
```

## 5. pgv.href() — Liens route-aware

```sql
pgv.href(p_path text) RETURNS text
```

Retourne `p_path` prefixe par le schema courant quand `pgv.route_prefix` est positionne (mode dev/multi-schema).

```sql
pgv.href('/')            -- '/' en app mode, '/cad/' en dev mode
pgv.href('/drawing?id=1') -- '/drawing?id=1' en app, '/cad/drawing?id=1' en dev
```

Le routeur positionne `pgv.route_prefix` automatiquement via `set_config()`. Les fonctions pages doivent utiliser `pgv.href()` pour generer des liens.

## 6. Module Functions Contract

Chaque module doit fournir :

### Obligatoire

```sql
-- Navigation items
{schema}.nav_items() RETURNS jsonb
-- Retourne: [{"href":"/","label":"Accueil"}, {"href":"/drawings","label":"Dessins"}]
-- Note: les href sont relatifs (sans prefix schema), le routeur les prefixe

-- Brand
{schema}.brand() RETURNS text
-- Retourne le nom affiche dans la nav (fallback: initcap(schema))
```

### Optionnel

```sql
-- Options de navigation
{schema}.nav_options() RETURNS jsonb
-- Retourne: {"burger": true} pour activer le burger menu responsive
-- Fallback: {} (nav standard)
```

### Pages et actions

```sql
-- Pages GET (0 ou 1 argument)
{schema}.get_index() RETURNS text
{schema}.get_drawings() RETURNS text
{schema}.get_drawing(p_id integer) RETURNS text

-- Actions POST (0 ou 1 argument)
{schema}.post_save(p_params jsonb) RETURNS text
{schema}.post_delete(p_id integer) RETURNS text
```

## 7. Navigation

### Navigation bar

`pgv.nav()` genere une `<nav>` avec :
- **Brand** — lien vers la racine du module (`pgv.href('/')`)
- **Items** — liens avec `aria-current="page"` sur l'item actif
- **Burger** — toggle responsive (optionnel, via `nav_options()`)
- **Theme toggle** — switch light/dark

```sql
pgv.nav(p_brand text, p_items jsonb, p_current text, p_options jsonb DEFAULT '{}')
```

### Back/Forward navigateur

Le shell gere le `popstate` via `window.onpopstate = function() { self.go(location.pathname, false); }`. Le second arg `false` evite un double `pushState`.

### Deep links / refresh

Le shell charge la page initiale via `boot()` qui appelle `go(location.pathname)`. Nginx doit etre configure avec un SPA fallback :

```nginx
location / {
    root /usr/share/nginx/html;
    try_files $uri $uri/ /index.html;
}
```

## 8. Tables — Markdown avec sort + pagination

Les tables sont generees en Markdown dans PL/pgSQL, converties cote client par `marked.js`. Le shell ajoute automatiquement le tri et la pagination.

### Usage

```sql
-- Table simple (sortable)
RETURN '<md>'
  || E'| Nom | Prix | Stock |\n| --- | --- | --- |\n'
  || format(E'| %s | %s | %s |\n', pgv.esc(r.name), pgv.money(r.price), pgv.badge('12','success'))
  || '</md>';

-- Table avec pagination (10 lignes/page)
RETURN '<md data-page="10">'
  || v_markdown_table
  || '</md>';
```

### Enhancement automatique

Le shell (`_enhance()`) :
1. Convertit `<md>` en HTML via `marked.parse()`
2. Emballe chaque `<table>` dans un `<div class="pgv-table">`
3. Ajoute le tri par colonne (clic sur `<th>`, class `pgv-sortable`)
4. Ajoute la pagination si `data-page` est specifie
5. Rend les lignes cliquables si elles contiennent un `<a href="/...">` interne

### Tri

Tri automatique sur clic d'en-tete :
- Detection numerique (ignore les symboles monnaie/separateurs)
- Detection dates au format `dd/mm/yyyy`
- Fallback : tri alphabetique `localeCompare()`

### Pagination

Avec `<md data-page="10">` :
- Barre de pagination (prev/next + numeros de pages)
- Ellipsis pour les grandes listes (> 7 pages)
- Compteur "1-10 sur 42"

## 9. pgView Primitives — Bibliotheque UI

Les primitives vivent dans le schema `pgv`, reutilisable par tout module.

### Atomes (formatage pur, IMMUTABLE/STABLE)

```sql
pgv.esc(text) -> text                           -- HTML escape (XSS)
pgv.badge(text, variant) -> text                -- <span> colore
pgv.money(numeric) -> text                      -- 1 299,00 EUR
pgv.date(date) -> text                          -- 9 mars 2026
pgv.status(text) -> text                        -- badge adapte au statut
pgv.filesize(bigint) -> text                    -- 2.4 MB
pgv.href(text) -> text                          -- route-aware link prefix
```

### Molecules (structure, composent les atomes)

```sql
-- Page complete : nav + container + contenu
pgv.page(p_brand text, p_title text, p_path text, p_nav jsonb, p_body text,
         p_options jsonb DEFAULT '{}') -> "text/html"

-- Navigation
pgv.nav(p_brand text, p_items jsonb, p_current text,
        p_options jsonb DEFAULT '{}') -> text

-- Card : article avec header et footer optionnels
pgv.card(p_title text, p_body text, p_footer text DEFAULT NULL) -> text

-- Grid : colonnes PicoCSS
pgv.grid(VARIADIC p_items text[]) -> text

-- Table Markdown depuis headers + rows
pgv.md_table(p_headers text[], p_rows text[][]) -> text

-- Liste cle-valeur (fiche detail)
pgv.dl(VARIADIC p_pairs text[]) -> text

-- KPI stat card
pgv.stat(p_label text, p_value text, p_detail text DEFAULT NULL) -> text

-- Breadcrumb
pgv.breadcrumb(VARIADIC p_parts text[]) -> text

-- Bouton d'action POST
pgv.action(p_endpoint text, p_label text, p_variant text DEFAULT 'primary',
           p_params text DEFAULT '{}', p_confirm text DEFAULT NULL) -> text

-- Erreur formatee
pgv.error(p_code text, p_title text, p_message text, p_hint text DEFAULT NULL) -> text
```

### Formulaires

```sql
pgv.form(p_action text, p_target text, VARIADIC p_fields text[]) -> text
pgv.input(p_name text, p_type text, p_label text,
          p_value text DEFAULT NULL, p_required boolean DEFAULT false) -> text
pgv.select(p_name text, p_label text, p_options jsonb,
           p_selected text DEFAULT NULL) -> text
pgv.textarea(p_name text, p_label text,
             p_value text DEFAULT NULL, p_rows int DEFAULT 3) -> text
```

### Composition d'une page

```sql
CREATE FUNCTION cad.get_drawings() RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  v_rows text[][] := '{}';
  r record;
BEGIN
  FOR r IN SELECT id, name, scale FROM cad.drawing ORDER BY name
  LOOP
    v_rows := v_rows || ARRAY[ARRAY[
      format('<a href="%s">%s</a>', pgv.href('/drawing?id=' || r.id), pgv.esc(r.name)),
      r.scale::text
    ]];
  END LOOP;

  RETURN pgv.card('Dessins',
    pgv.md_table(ARRAY['Nom', 'Echelle'], v_rows)
  );
END;
$$;
```

Note : la fonction retourne juste le body. Le routeur `pgv.route()` emballe dans `pgv.page()` avec la nav et le titre.

## 10. CSS — pgview.css

Les styles vivent dans `pgview.css` avec des CSS custom properties `--pgv-*`. Themes light/dark via selecteur `[data-theme]`.

### Regles strictes

- **CSS classes, JAMAIS inline styles** — les primitives `pgv.*` utilisent `class="pgv-*"`
- **Pas de CSS custom** dans les modules — tout passe par les classes `pgv-*` existantes
- **Ne jamais modifier** `pgview.css` depuis un module — c'est du code plateforme

### Classes disponibles

```
pgv-brand          Brand link dans la nav
pgv-badge-*        Badges colores (success, danger, warning, info, gold, silver)
pgv-table          Wrapper table (overflow-x, borders)
pgv-sortable       En-tete de colonne triable
pgv-pager          Barre de pagination
pgv-nav-burger     Nav avec burger menu
pgv-burger         Bouton burger
pgv-menu           Menu items (collapsed en mobile)
pgv-menu-open      Menu ouvert
pgv-theme-toggle   Bouton theme toggle
toast-success      Toast succes
toast-error        Toast erreur
```

## 11. PostgREST Configuration

```yaml
# docker-compose.yml
postgrest:
  image: postgrest/postgrest:v12.2.3
  environment:
    PGRST_DB_URI: postgres://authenticator:authenticator@postgres:5432/postgres
    PGRST_DB_SCHEMAS: pgv,cad,cad_ut          # schemas exposes
    PGRST_DB_ANON_ROLE: web_anon
```

### Grants

```sql
-- Le routeur est le seul point d'entree expose
GRANT USAGE ON SCHEMA pgv TO web_anon;
GRANT EXECUTE ON FUNCTION pgv.route(text, text, text, jsonb) TO web_anon;

-- Les fonctions internes (get_*, post_*, nav_items, etc.) ne sont PAS exposees directement
-- Le routeur les appelle via EXECUTE format()
```

### Content-Profile header

Pour les actions POST via `data-rpc`, le shell envoie le header `Content-Profile` avec le schema courant. Cela permet a PostgREST de router vers le bon schema quand plusieurs schemas exposent une fonction du meme nom.

## 12. Conventions

### Nommage fonctions

```
{schema}.get_*()          -> pages GET (retournent du body HTML)
{schema}.post_*()         -> actions POST (retournent toast/redirect)
{schema}.nav_items()      -> items de navigation (jsonb array)
{schema}.brand()          -> nom du module (text)
{schema}.nav_options()    -> options nav (jsonb, optionnel)
pgv.*()                   -> primitives UI reusables (schema dedie)
```

### Nommage routes (URL)

```
GET  /                    -> get_index()
GET  /drawings            -> get_drawings()
GET  /drawing?id=42       -> get_drawing(p_id integer)
POST /save                -> post_save(p_params jsonb)
POST /delete              -> post_delete(p_id integer)
GET  /settings            -> get_settings()
POST /settings            -> post_settings(p_params jsonb)
```

Les parametres dynamiques passent par query string (`?id=42`), pas par segments de path (`/drawing/42`).

### HTML genere

- Utiliser les balises semantiques PicoCSS : `<main>`, `<article>`, `<nav>`, `<header>`, `<footer>`
- Tables via `<md>` Markdown (converti client-side par marked.js)
- Classes `pgv-*` du CSS partage, jamais d'inline styles
- `pgv.esc()` sur tout contenu utilisateur (XSS)
- Liens internes via `pgv.href()` pour le support multi-schema
- Actions via `data-rpc` + `data-params`, pas de `onclick` inline
