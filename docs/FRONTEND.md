# FRONTEND.md — pgView + htmx Reference

> Stack UI/UX définitive pour les applications pgView.
> Ce document est la référence pour tout développement frontend sur la plateforme.

## Stack

```
htmx 2          (14 KB, CDN)      Interactions déclaratives, partials, navigation
PicoCSS 2       (10 KB, CDN)      Style classless, responsive, dark mode
marked.js       (8 KB, CDN)       Markdown → HTML (tables)
pdf.js          (lazy, CDN)       Preview PDF inline (chargé à la demande)
PostgREST 12+   (transport)       HTTP ↔ PL/pgSQL, zéro code serveur
PL/pgSQL        (runtime)         Génère le HTML, routing, logique métier
```

**Zéro build, zéro npm, zéro framework JS.** Le shell HTML est un fichier statique < 100 lignes.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  Browser : shell.html + htmx (déclaratif)                │
├──────────────────────────────────────────────────────────┤
│  PostgREST  →  POST /rpc/page, /rpc/frag_*               │
│               Content-Type: text/html (domain trick)      │
├──────────────────────────────────────────────────────────┤
│  PL/pgSQL : page() → HTML complet                        │
│             frag_*() → fragments HTML (partials htmx)    │
│             pgv.* → primitives UI composables             │
│             set_config('response.headers', ...) → HX-*   │
├──────────────────────────────────────────────────────────┤
│  PostgreSQL : tables + contraintes + RLS                  │
└──────────────────────────────────────────────────────────┘
```

## 1. Le Domain `text/html`

PostgREST retourne du JSON par défaut. Pour retourner du HTML brut, créer un domain PostgreSQL :

```sql
CREATE DOMAIN "text/html" AS TEXT;
```

Toute fonction retournant `"text/html"` envoie directement du HTML au navigateur :

```sql
CREATE FUNCTION app.page(p_path text, p_body jsonb DEFAULT '{}')
RETURNS "text/html" LANGUAGE plpgsql AS $$
BEGIN
  RETURN '<main class="container"><h2>Hello</h2></main>';
END;
$$;
```

PostgREST sert le résultat avec `Content-Type: text/html` — htmx le swap directement dans le DOM.

## 2. Shell HTML

Le shell est le seul fichier côté client. htmx gère la navigation et les formulaires — le JS custom se limite à la conversion `<md>` et aux initialisations.

```html
<!DOCTYPE html>
<html lang="fr" data-theme="light">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>App</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css">
  <script src="https://unpkg.com/htmx.org@2"></script>
  <script src="https://unpkg.com/htmx-ext-response-targets@2/response-targets.js"></script>
  <script src="https://unpkg.com/htmx-ext-preload@2/preload.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
  <style>
    .htmx-indicator { opacity: 0; transition: opacity 200ms; }
    .htmx-request .htmx-indicator { opacity: 1; }
    .htmx-request.htmx-indicator { opacity: 1; }
    tr[style*="cursor"]:hover { background: var(--pico-table-row-stripped-background-color); }
    #error-toast:empty { display: none; }
    #error-toast { position: fixed; bottom: 1rem; right: 1rem; z-index: 999; }
  </style>
</head>
<body hx-ext="response-targets, preload"
      hx-headers='{"Accept": "text/html"}'
      hx-target="#app"
      hx-swap="innerHTML show:window:top"
      hx-target-error="#error-toast">

  <div id="app"
       hx-get="/rpc/page?p_path=/"
       hx-trigger="load"
       hx-push-url="/">
    Chargement...
  </div>

  <div id="error-toast" role="alert"></div>

  <script>
    // --- Markdown conversion + clickable rows after each swap ---
    htmx.on('htmx:afterSwap', function(evt) {
      var target = evt.detail.target;

      // Convert <md> blocks to HTML tables
      target.querySelectorAll('md').forEach(function(el) {
        var div = document.createElement('div');
        div.innerHTML = marked.parse(el.innerHTML.trim());
        el.parentNode.replaceChild(div, el);
      });

      // Make table rows with internal links clickable
      target.querySelectorAll('tbody tr').forEach(function(tr) {
        var a = tr.querySelector('a[href^="/"]');
        if (!a) return;
        tr.style.cursor = 'pointer';
        tr.addEventListener('click', function(e) {
          if (e.target.closest('a, button')) return;
          htmx.ajax('GET', '/rpc/page?p_path=' + encodeURIComponent(a.getAttribute('href')),
            { target: '#app', swap: 'innerHTML', pushUrl: a.getAttribute('href') });
        });
      });
    });

    // --- Clear error toast on next successful request ---
    htmx.on('htmx:afterRequest', function(evt) {
      if (!evt.detail.failed) {
        document.getElementById('error-toast').innerHTML = '';
      }
    });
  </script>
</body>
</html>
```

**~60 lignes.** htmx gère navigation, formulaires, partials, history. Le JS ne fait que `<md>` conversion et clickable rows.

## 3. Routing — Pages et Fragments

### Pages (full page swap)

`page(p_path, p_body)` retourne le HTML complet d'une page (nav + contenu). Appelé par htmx pour la navigation principale.

```sql
CREATE FUNCTION app.page(p_path text, p_body jsonb DEFAULT '{}')
RETURNS "text/html" LANGUAGE plpgsql AS $$
BEGIN
  CASE
    WHEN p_path = '/'              THEN RETURN app.pgv_dashboard();
    WHEN p_path LIKE '/docs%'      THEN RETURN docman.page(p_path, p_body);
    WHEN p_path LIKE '/clients%'   THEN RETURN clients.page(p_path, p_body);
    ELSE RETURN pgv.page('404', p_path, app.nav_items(),
                  '<p>Page non trouvee : ' || pgv.esc(p_path) || '</p>');
  END CASE;
END;
$$;
```

Appelé via htmx sur les liens :

```html
<a href="/docs"
   hx-get="/rpc/page?p_path=/docs"
   hx-push-url="/docs"
   preload>Documents</a>
```

### Fragments (partial swap)

Les fragments ne retournent qu'un morceau de HTML. htmx swap le fragment dans un `<div>` ciblé sans recharger la page entière.

```sql
-- Fragment : juste la liste filtrée, pas toute la page
CREATE FUNCTION docman.frag_search(p_filters jsonb DEFAULT '{}')
RETURNS "text/html" LANGUAGE plpgsql AS $$
DECLARE
  v_results jsonb;
BEGIN
  v_results := docman.search(p_filters);
  RETURN docman.pgv_document_table(v_results);
END;
$$;
```

Appelé depuis un formulaire de recherche dans la page :

```html
<form hx-post="/rpc/frag_search"
      hx-target="#results"
      hx-swap="innerHTML"
      hx-replace-url="false">
  <input name="p_filters" type="hidden" id="filters">
  <input type="search" name="q" placeholder="Rechercher..."
         hx-post="/rpc/frag_search"
         hx-trigger="input changed delay:300ms"
         hx-target="#results">
</form>
<div id="results">
  <!-- htmx swap le fragment ici -->
</div>
```

### Convention de nommage

```
page(path, body)     → HTML complet (nav + contenu), pour la navigation
frag_*(params)       → fragment HTML, pour les partials htmx
pgv_*(data)          → composant HTML réutilisable (pas exposé via PostgREST)
```

## 4. Response Headers — Contrôle htmx depuis PL/pgSQL

PostgREST lit `response.headers` pour ajouter des headers HTTP. Cela permet de piloter htmx depuis le serveur.

```sql
-- Redirect après un POST (ex: création)
PERFORM set_config('response.headers',
  '[{"HX-Redirect": "/docs/' || v_id || '"}]', true);
RETURN '';

-- Redirect SPA (sans full reload)
PERFORM set_config('response.headers',
  '[{"HX-Location": "{\"path\":\"/docs\", \"target\":\"#app\"}"}]', true);

-- Trigger un événement côté client (toast, refresh d'un compteur)
PERFORM set_config('response.headers',
  '[{"HX-Trigger": "{\"showToast\":{\"level\":\"success\",\"message\":\"Document classifie\"}}"}]', true);

-- Changer la cible du swap (ex: erreur vers un toast)
PERFORM set_config('response.headers',
  '[{"HX-Retarget": "#error-toast"}, {"HX-Reswap": "innerHTML"}]', true);
RETURN '<article class="pico-background-red-500">Erreur : document introuvable</article>';

-- Out-of-band : mettre à jour un compteur en plus du contenu principal
-- (inclure dans le HTML retourné)
-- <span id="inbox-count" hx-swap-oob="true">12</span>
```

### Patterns courants

| Action | Header | Exemple |
|--------|--------|---------|
| Redirect POST→GET | `HX-Redirect` | Après création de document |
| SPA navigate | `HX-Location` | Navigation sans full reload |
| Toast/notification | `HX-Trigger` | Confirmation d'action |
| Forcer refresh | `HX-Refresh: true` | Après changement global |
| Update compteur | `hx-swap-oob` dans le HTML | Badge inbox |

## 5. Formulaires

htmx gère les formulaires nativement. Plus besoin de `post()` custom.

### Formulaire simple

```sql
-- Généré par PL/pgSQL :
RETURN '
<form hx-post="/rpc/page"
      hx-vals=''{"p_path": "/docs/classify"}''
      hx-target="#app">
  <label>Type
    <select name="doc_type">
      <option value="facture">Facture</option>
      <option value="contrat">Contrat</option>
    </select>
  </label>
  <label>Date du document
    <input type="date" name="document_date">
  </label>
  <label>Resume
    <textarea name="summary" rows="3"></textarea>
  </label>
  <button type="submit">Classifier</button>
</form>';
```

### Formulaire avec partial (sans recharger la page)

```sql
RETURN '
<form hx-post="/rpc/frag_classify"
      hx-target="#classification-result"
      hx-swap="innerHTML"
      hx-indicator="#classify-spinner">
  <input type="hidden" name="p_doc_id" value="' || p_doc_id || '">
  <select name="p_doc_type">...</select>
  <button type="submit">
    Classifier
    <span id="classify-spinner" class="htmx-indicator" aria-busy="true"></span>
  </button>
</form>
<div id="classification-result"></div>';
```

### Loading state (PicoCSS natif)

PicoCSS affiche un spinner natif sur tout element avec `aria-busy="true"` :

```html
<button type="submit" class="htmx-indicator" aria-busy="true">
  Classifier
</button>
```

htmx ajoute `.htmx-request` pendant la requête → le CSS `.htmx-request.htmx-indicator` rend l'élément visible → PicoCSS affiche le spinner via `aria-busy`.

### Confirmation

```html
<button hx-post="/rpc/frag_delete_doc"
        hx-vals='{"p_doc_id": "abc-123"}'
        hx-confirm="Supprimer ce document ?"
        hx-target="#app"
        class="secondary">
  Supprimer
</button>
```

## 6. Upload de fichiers

```html
<form hx-post="/rpc/frag_upload"
      hx-encoding="multipart/form-data"
      hx-target="#upload-result">
  <input type="file" name="document" accept=".pdf,.jpg,.png">
  <button type="submit">Importer</button>
</form>
<div id="upload-result"></div>
```

Note : PostgREST ne gère pas nativement le multipart. Pour l'upload, deux options :

1. **Supabase Storage** — upload vers le bucket, puis `pg_notify` ou appel RPC pour enregistrer
2. **Base64 dans un champ** — petits fichiers uniquement
3. **Endpoint Express dédié** — le serveur MCP workbench peut exposer un `/upload`

Le pattern recommandé avec Supabase :

```
Browser → Supabase Storage (upload direct)
       → POST /rpc/frag_import (enregistre dans docman)
```

## 7. pgView Primitives — Bibliothèque UI

Les primitives vivent dans le schéma `pgv`, réutilisable par toute app.

### Atomes (formatage pur, IMMUTABLE)

```sql
pgv.esc(text) -> text                           -- HTML escape (XSS)
pgv.badge(text, variant) -> text                -- <span> coloré
pgv.money(numeric) -> text                      -- 1 299,00 €
pgv.date(date) -> text                          -- 9 mars 2026
pgv.status(text) -> text                        -- badge adapté au statut
pgv.filesize(bigint) -> text                    -- 2.4 MB
```

### Molecules (structure, composent les atomes)

```sql
-- Page complete : nav + container + contenu
pgv.page(p_title text, p_path text, p_nav jsonb, p_body text) -> "text/html"

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

-- Navigation avec lien actif
pgv.nav(p_brand text, p_items jsonb, p_current text) -> text

-- Breadcrumb
pgv.breadcrumb(VARIADIC p_parts text[]) -> text
```

### Formulaires (htmx-aware)

```sql
-- Formulaire htmx
pgv.form(p_action text, p_target text, VARIADIC p_fields text[]) -> text
-- Genere : <form hx-post="{action}" hx-target="{target}">...

-- Champs
pgv.input(p_name text, p_type text, p_label text,
          p_value text DEFAULT NULL, p_required boolean DEFAULT false) -> text

pgv.select(p_name text, p_label text, p_options jsonb,
           p_selected text DEFAULT NULL) -> text

pgv.textarea(p_name text, p_label text,
             p_value text DEFAULT NULL, p_rows int DEFAULT 3) -> text

-- Bouton d'action (POST htmx)
pgv.action(p_endpoint text, p_label text,
           p_target text DEFAULT '#app',
           p_confirm text DEFAULT NULL,
           p_variant text DEFAULT 'primary') -> text
-- Genere : <button hx-post="{endpoint}" hx-target="{target}"
--                  hx-confirm="{confirm}" class="{variant}">
```

### Composition d'une page

```sql
CREATE FUNCTION docman.pgv_inbox() RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  v_docs jsonb;
  v_rows text[][] := '{}';
  r record;
BEGIN
  v_docs := docman.inbox();

  FOR r IN SELECT * FROM jsonb_array_elements(v_docs)
  LOOP
    v_rows := v_rows || ARRAY[ARRAY[
      format('<a href="/docs/%s">%s</a>', r.value->>'id', pgv.esc(r.value->>'filename')),
      pgv.badge(coalesce(r.value->>'doc_type', 'non classe'), 'warning'),
      pgv.filesize((r.value->>'size_bytes')::bigint),
      pgv.date((r.value->>'created_at')::date)
    ]];
  END LOOP;

  RETURN pgv.page('Inbox', '/docs/inbox', app.nav_items(),
    pgv.card('Documents non classes',
      pgv.md_table(ARRAY['Fichier', 'Type', 'Taille', 'Date'], v_rows)
    )
  );
END;
$$;
```

## 8. Navigation htmx

### Liens internes

Tous les liens internes passent par `page()` avec `hx-push-url` pour le SPA routing :

```html
<!-- Genere par pgv.nav() -->
<a href="/docs"
   hx-get="/rpc/page?p_path=/docs"
   hx-push-url="/docs"
   preload>Documents</a>
```

Le `preload` (extension htmx) precharge au hover pour une navigation instantanee.

### Back/Forward navigateur

htmx gere le `popstate` nativement quand `hx-push-url` est utilise. Rien a coder.

### Deep links / refresh

Le shell charge la page initiale via `hx-trigger="load"` sur `#app`. Pour supporter les deep links (ex: `/docs/abc-123`), le shell doit lire le hash ou le path :

```html
<div id="app"
     hx-get="/rpc/page"
     hx-vals='js:{"p_path": window.location.hash.slice(1) || "/"}'
     hx-trigger="load"
     hx-push-url="false">
</div>
```

Ou avec un serveur statique qui redirige tout vers `index.html` (SPA fallback classique).

## 9. Out-of-Band Updates

Mettre a jour plusieurs zones de la page en une seule reponse :

```sql
-- La reponse principale va dans hx-target
-- Les elements avec hx-swap-oob="true" sont swappe independamment
RETURN '
<div>Contenu principal mis a jour</div>
<span id="inbox-count" hx-swap-oob="true">3</span>
<span id="last-activity" hx-swap-oob="true">il y a 2 min</span>';
```

Utile pour : compteurs dans la nav, timestamps, statuts.

## 10. Error Handling

### Cote serveur

```sql
-- Erreur metier → retourner du HTML d'erreur
IF NOT FOUND THEN
  PERFORM set_config('response.status', '404', true);
  RETURN '<article style="color:var(--pico-del-color)">
    <header>Document introuvable</header>
    <p>Le document demande n''existe pas.</p>
    <a href="/docs" hx-get="/rpc/page?p_path=/docs" hx-push-url="/docs">
      Retour a la liste</a>
  </article>';
END IF;
```

### Cote client

L'extension `response-targets` route les erreurs HTTP vers `#error-toast` :

```html
<body hx-target-error="#error-toast">
```

Le toast se vide automatiquement a la prochaine requete reussie (voir le script du shell).

## 11. PostgREST Configuration

```yaml
# docker-compose.yml
postgrest:
  image: postgrest/postgrest:v12.2.3
  environment:
    PGRST_DB_URI: postgres://authenticator:authenticator@postgres:5432/postgres
    PGRST_DB_SCHEMAS: app,docman            # schemas exposes
    PGRST_DB_ANON_ROLE: web_anon
    PGRST_SERVER_CORS_ALLOWED_ORIGINS: "*"  # restreindre en prod
```

### Grants

```sql
-- Seules les fonctions publiques sont exposees
GRANT USAGE ON SCHEMA app TO web_anon;
GRANT EXECUTE ON FUNCTION app.page(text, jsonb) TO web_anon;

-- Les fragments aussi
GRANT EXECUTE ON FUNCTION docman.frag_search(jsonb) TO web_anon;
GRANT EXECUTE ON FUNCTION docman.frag_classify(uuid, text, date, text) TO web_anon;

-- Les fonctions internes (pgv_*, metier) ne sont PAS exposees
-- PostgREST n'expose que ce qui a un GRANT
```

## 12. Conventions

### Nommage fonctions

```
app.page(path, body)       → routeur top-level, retourne "text/html"
{schema}.page(path, body)  → sous-routeur de domaine
{schema}.frag_*(params)    → fragments htmx (partials)
{schema}.pgv_*(data)       → composants HTML internes (pas exposes)
pgv.*(params)              → primitives UI reusables (schema dedie)
```

### Nommage routes

```
/                          → dashboard
/{domaine}                 → liste
/{domaine}/{id}            → detail
/{domaine}/{id}/{action}   → action (POST)
/{domaine}/inbox           → elements non traites
/{domaine}/search          → recherche
```

### HTML genere

- Utiliser les balises semantiques PicoCSS : `<main>`, `<article>`, `<nav>`, `<header>`, `<footer>`
- Tables via `<md>` Markdown (converti client-side par marked.js)
- Pas de classes CSS custom — PicoCSS classless + attributs ARIA
- `pgv.esc()` sur tout contenu utilisateur (XSS)
- Pas d'inline `onclick` — utiliser les attributs `hx-*`

### Extensions htmx chargees

| Extension | Usage |
|-----------|-------|
| `response-targets` | Route erreurs HTTP vers `#error-toast` |
| `preload` | Precharge les liens au hover |

Extensions optionnelles (ajouter si besoin) :

| Extension | Quand |
|-----------|-------|
| `idiomorph` | Si on ajoute Alpine.js (preserve le DOM state) |
| `sse` | Si on a besoin de temps reel (notifications) |
| `head-support` | Si les fragments modifient le `<title>` |

### Alpine.js

**Pas dans la stack initiale.** A ajouter uniquement si on a besoin de :
- Tabs, accordions (PicoCSS n'en a pas)
- Toggle show/hide sans round-trip serveur
- State local (panier, filtres multi-criteres)

Si ajoute : utiliser `idiomorph` extension pour preserver le state Alpine lors des swaps htmx.

## 13. Migration depuis le shell actuel

| Ancien (pgview.html) | Nouveau (htmx) |
|----------------------|-----------------|
| `go(path)` | `hx-get="/rpc/page?p_path=/path" hx-push-url="/path"` |
| `post(path, body)` | `hx-post="/rpc/page" hx-vals='{"p_path":"/path"}'` |
| `render(html)` | htmx `hx-swap="innerHTML"` automatique |
| `<!-- redirect:/path -->` | `set_config('response.headers', '[{"HX-Redirect":"/path"}]')` |
| `<script>` inline | `HX-Trigger` events |
| `fetch()` custom | Tout declaratif via attributs `hx-*` |

## 14. Deploiement

### Local (dev)

```
docker compose up -d    # PostgreSQL + PostgREST
# shell.html servi par nginx ou fichier local
```

### Supabase (prod)

```
1. Deploy fonctions via pg_func_load
2. GRANT sur page() et frag_*()
3. shell.html sur Supabase Storage ou CDN
4. Changer l'endpoint : /rest/v1/rpc/page + header apikey
5. Auth JWT via current_setting('request.jwt.claims')
```
