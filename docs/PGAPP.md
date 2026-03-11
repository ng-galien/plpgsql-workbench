# PGAPP — PL/pgSQL Application Platform

## Vision

Construire des applications completes avec PostgreSQL comme seul runtime.
Trois couches, un seul modele de navigation :

```
+---------------------------------------------+
|  Browser : Alpine.js shell (SPA)            |  UI
+---------------------------------------------+
|  PostgREST  ->  pgv.route(schema, path,     |  Transport
|                            method, params)   |
+---------------------------------------------+
|  PL/pgSQL : router + get_*/post_* functions |  Backend
|  PostgreSQL : tables + contraintes + RLS    |  Storage
+---------------------------------------------+
|  MCP Workbench (plpgsql://)                 |  Dev/Ops
+---------------------------------------------+
```

Pas de serveur applicatif. La DB est l'app.

## 1. API Router

### Signature

```sql
CREATE FUNCTION api(
  p_method text,        -- GET | POST | PUT | DELETE
  p_path   text,        -- /clients/42/commandes
  p_body   jsonb DEFAULT '{}'
) RETURNS jsonb
```

### Contrat de réponse

Toute réponse suit le même envelope :

```jsonc
{
  "ok": true,
  "data": { ... },           // objet ou tableau
  "_links": {                // HATEOAS — toujours présent
    "self": "/clients/42",
    "list": "/clients",
    "commandes": "/clients/42/commandes",
    "nouveau_devis": {
      "href": "/devis",
      "method": "POST",
      "schema": {            // décrit le formulaire pour l'action
        "client_id": { "type": "integer", "value": 42, "readonly": true },
        "modele_id": { "type": "integer", "required": true },
        "options":   { "type": "integer[]" }
      }
    }
  },
  "_meta": {                 // optionnel
    "total": 15,
    "page": 1,
    "per_page": 20
  }
}
```

Erreur :

```jsonc
{
  "ok": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "client 99 not found",
    "path": "/clients/99"
  },
  "_links": {
    "list": "/clients"
  }
}
```

### Routing

Le routeur utilise du pattern matching sur le path :

```sql
CASE
  -- Collection
  WHEN p_path = '/clients' AND p_method = 'GET' THEN
    RETURN list_clients(p_body);
  WHEN p_path = '/clients' AND p_method = 'POST' THEN
    RETURN create_client(p_body);

  -- Ressource
  WHEN p_path ~ '^/clients/(\d+)$' AND p_method = 'GET' THEN
    RETURN get_client(path_id(p_path, 2));
  WHEN p_path ~ '^/clients/(\d+)$' AND p_method = 'PUT' THEN
    RETURN update_client(path_id(p_path, 2), p_body);

  -- Sous-ressource
  WHEN p_path ~ '^/clients/(\d+)/commandes$' AND p_method = 'GET' THEN
    RETURN list_commandes_client(path_id(p_path, 2));

  -- Actions
  WHEN p_path ~ '^/devis/(\d+)/valider$' AND p_method = 'POST' THEN
    RETURN valider_devis(path_id(p_path, 2));
END CASE;
```

### Helpers

```sql
-- Extraire l'ID d'un segment de path : /clients/42 → 42
CREATE FUNCTION path_id(p_path text, p_segment integer) RETURNS integer

-- Wrapper réponse succès
CREATE FUNCTION ok_response(p_data jsonb, p_links jsonb) RETURNS jsonb

-- Wrapper réponse erreur
CREATE FUNCTION err_response(p_code text, p_message text, p_links jsonb DEFAULT '{}') RETURNS jsonb

-- Wrapper réponse liste avec pagination
CREATE FUNCTION list_response(p_data jsonb, p_total integer, p_links jsonb) RETURNS jsonb
```

### PostgREST

Un seul endpoint exposé :

```
POST /rpc/api  { "p_method": "GET", "p_path": "/clients", "p_body": {} }
```

Config PostgREST :
```
PGRST_DB_SCHEMAS=app          # schéma applicatif
PGRST_DB_ANON_ROLE=web_anon   # rôle anonyme
```

Grants :
```sql
GRANT EXECUTE ON FUNCTION app.api TO web_anon;
-- Les fonctions internes ne sont PAS exposées
```

## 2. VS Code Extension — HATEOAS Browser

### Principe

L'extension ne connaît pas le domaine métier. Elle sait :
1. Appeler `api(method, path, body)` → jsonb
2. Lire le `data` et l'afficher
3. Lire les `_links` et les rendre navigables
4. Générer un formulaire à partir du `schema` d'un lien action

### Composants

#### TreeView — Navigation

```
PGAPP: localhost:3000
├── clients                    ← GET /clients
│   ├── Marie Dupont           ← GET /clients/1
│   │   ├── commandes          ← _links.commandes
│   │   └── devis              ← _links.devis
│   └── Jean Martin
├── catalogue                  ← GET /catalogue
│   ├── Fumoir Petit
│   └── Fumoir Grand
└── dashboard                  ← GET /dashboard
```

Le tree se construit dynamiquement en suivant les `_links`. Pas de hard-code.

#### WebView — Affichage

| Type de data | Rendu |
|-------------|-------|
| Objet `{}` | Fiche clé-valeur |
| Tableau `[]` | Table avec colonnes auto-détectées |
| Objet avec `_links` action | Boutons d'action |
| Lien avec `schema` | Formulaire auto-généré |

#### Formulaires

Quand un `_link` a un `schema`, l'extension génère un formulaire :

```jsonc
"nouveau_devis": {
  "href": "/devis",
  "method": "POST",
  "schema": {
    "client_id": { "type": "integer", "value": 42, "readonly": true },
    "modele_id": { "type": "integer", "required": true, "enum": [1, 2, 3] },
    "options":   { "type": "integer[]", "enum": [10, 11, 12] },
    "notes":     { "type": "text" }
  }
}
```

→ Formulaire avec champs typés, valeurs par défaut, listes déroulantes, validation.
Submit → `api('POST', '/devis', { ...form values })`.

#### Types de champs schema

| Type | Rendu |
|------|-------|
| `integer`, `numeric` | Input number |
| `text` | Input text / textarea (si `multiline: true`) |
| `boolean` | Checkbox |
| `date`, `timestamptz` | Date picker |
| `integer[]` | Multi-select (si `enum` fourni) |
| Avec `enum` | Select / dropdown |
| Avec `readonly: true` | Affiché mais non éditable |
| Avec `required: true` | Marqué obligatoire |

### Configuration extension

```jsonc
// settings.json
{
  "pgapp.connections": [
    {
      "name": "Fumoir (local)",
      "url": "http://localhost:3000/rpc/api",
      "root": "/dashboard"        // path d'entrée
    }
  ]
}
```

### Workflow utilisateur

1. Ouvrir le TreeView → l'extension appelle `GET /dashboard`
2. Cliquer sur "clients" dans les `_links` → appelle `GET /clients`
3. Voir la liste en table dans le WebView
4. Cliquer sur un client → `GET /clients/42`
5. Voir la fiche client avec boutons (commandes, nouveau devis)
6. Cliquer "Nouveau devis" → formulaire auto-généré depuis le `schema`
7. Soumettre → `POST /devis` → réponse avec `_links.self` → navigation auto

## 3. Lien avec le MCP Workbench

Le workbench continue à piloter le dev :

| Action | Outil |
|--------|-------|
| Créer une table | `apply sql/migrations` |
| Développer une fonction métier | `set` / `edit` |
| Tester | `test` |
| Coverage | `coverage` |
| Versionner | `dump` |
| Débuguer une route | `query SELECT api('GET', '/clients/1', '{}')` |
| Ajouter une route | `edit` le routeur, `test`, c'est live |

Les deux systèmes partagent le même modèle mental : **des URIs navigables partout**.

| Couche | URI | Exemple |
|--------|-----|---------|
| MCP | `plpgsql://schema/function/name` | `plpgsql://app/function/api` |
| API | `/path` | `/clients/42/commandes` |
| Extension | suit les `_links` | clic → clic → clic |

## 4. pgView — Server-Side Rendering en PL/pgSQL

### Principe

PostgreSQL genere le HTML. Pas de framework JS. Le navigateur est un afficheur.

```
+----------------------------------------------+
|  Browser : Alpine.js shell (~150 lignes JS)  |
+----------------------------------------------+
|  PostgREST  ->  POST /rpc/route              |
|    {schema, path, method, params}            |
+----------------------------------------------+
|  pgv.route() -> introspect pg_proc           |
|    -> dispatch get_*/post_* functions         |
|    -> GET: pgv.page() layout wrapping         |
|    -> POST: raw HTML (toast/redirect)         |
+----------------------------------------------+
```

### Routeur pgv.route()

Un routeur unique, generique, base sur pg_proc introspection :

```sql
pgv.route(p_schema text, p_path text, p_method text DEFAULT 'GET', p_params jsonb DEFAULT '{}')
RETURNS "text/html"
```

Le routeur :
1. Derive le nom de fonction : `lower(method) || '_' || path_segments`
   - `GET /` -> `get_index`
   - `GET /drawings` -> `get_drawings`
   - `POST /save` -> `post_save`
2. Charge `nav_items()`, `brand()`, `nav_options()` du schema cible
3. Introspect la signature de la fonction via `pg_proc` (max 1 arg)
4. Dispatch selon le type d'argument (0 args, jsonb, scalaire, composite)
5. GET : emballe dans `pgv.page()` avec nav + titre
6. POST : retourne le HTML brut (toast/redirect templates)

**Pas de CASE, pas de routeur a maintenir.** Ajouter une page = creer une fonction `get_xxx()`.

### Shell SPA (Alpine.js)

Le frontend est un fichier HTML statique (`index.html`) :
- **Alpine.js** — composant `pgview` (state, events, navigation)
- **PicoCSS** via CDN pour le style classless
- `go(path)` : fetch `/rpc/route` -> render HTML dans `#app`
- `post(endpoint, data)` : fetch avec `Content-Profile` header
- Interception des clics sur `<a href="/">` pour navigation SPA
- `_enhance()` : markdown, tables triables, rows cliquables, scripts inline
- Toast, dialog, theme toggle
- Deux modes : app (schema fixe) et dev (multi-schema)

Voir [FRONTEND.md](FRONTEND.md) pour la reference complete.

### Helpers HTML (fonctions pgv.*)

```sql
pgv.esc(text)                     -- echappement HTML (XSS)
pgv.badge(text, variant)          -- <span> colore (success/danger/warning/info)
pgv.money(numeric)                -- 1 299,00 EUR
pgv.date(date)                    -- 9 mars 2026
pgv.href(text)                    -- lien route-aware (prefix schema en dev mode)
pgv.card(title, body, footer)     -- article avec header/footer
pgv.grid(VARIADIC items)          -- colonnes PicoCSS
pgv.md_table(headers, rows)       -- table Markdown
pgv.action(endpoint, label, ...)  -- bouton POST avec data-rpc
pgv.nav(brand, items, current, options) -- navigation avec burger optionnel
```

### Avantages

- **0 dependances build** — pas de npm, pas de bundler
- **Hot reload** — `pg_func_set` la fonction, F5, c'est live
- **Testable** — `pg_query SELECT pgv.route('cad', '/', 'GET')` dans le workbench
- **Perenne** — SQL ne vieillit pas, pas de breaking changes framework
- **Zero routing code** — pg_proc introspection, ajouter une page = creer une fonction

## 5. Architecture : Schema = Module (DDD)

### Principe

Chaque schéma PostgreSQL est un **bounded context** — une unité fonctionnelle autonome avec ses tables, ses fonctions, son routeur, et ses tests.

```
clients/                       -- domaine clients
  ├── tables: clients, contacts, adresses
  ├── fonctions: get_index, get_detail, post_create, post_update
  ├── nav_items(), brand()     -- navigation
  └── clients_ut/              -- tests pgTAP

catalogue/                     -- domaine produits
  ├── tables: modeles, nomenclature, options
  ├── fonctions: get_index, get_detail, get_pricing
  ├── nav_items(), brand()
  └── catalogue_ut/

commandes/                     -- workflow commandes
  ├── tables: devis, commandes, lignes
  ├── fonctions: get_index, get_detail, post_valider, post_annuler
  ├── nav_items(), brand()
  └── commandes_ut/
```

### Routage multi-schema

Le routeur `pgv.route()` est generique : il dispatch vers n'importe quel schema. Pas de routeur top-level a maintenir.

En mode dev (multi-schema), l'URL contient le schema : `/{schema}/path`. Le shell extrait le schema et appelle `pgv.route(schema, path, method, params)`.

En mode app (single-schema), un `<meta name="pgv-schema" content="mon_app">` fixe le schema. Les URLs sont simples : `/path`.

### Dépendances explicites

Les appels cross-schéma sont visibles dans le code :

```sql
-- commandes.creer_devis() appelle :
v_prix := catalogue.calculer_prix(p_modele_id, p_options);
v_client := clients.get_client(p_client_id);
```

Le MCP le montre via `calls:` dans la sortie de `get`.

### Isolation

- Chaque schéma a ses propres `GRANT`
- RLS par schéma si nécessaire
- `search_path` contrôlé : pas d'accès implicite cross-schéma
- Un schéma peut évoluer indépendamment (migration par domaine)

### Mapping MCP

```
get plpgsql://clients              -- naviguer un domaine
get plpgsql://commandes/function/* -- voir toutes les fonctions d'un domaine
coverage plpgsql://compta          -- couverture par domaine
test plpgsql://clients_ut          -- tests d'un domaine
dump --target plpgsql://catalogue  -- export d'un domaine
```

## 6. Structure projet type

```
mon-app/
├── sql/
│   ├── migrations/
│   │   ├── 001_clients.sql
│   │   ├── 002_catalogue.sql
│   │   └── 003_commandes.sql
│   ├── seed/
│   │   └── 001_data.sql
│   └── functions/              ← dump par domaine
│       ├── clients/
│       ├── catalogue/
│       ├── commandes/
│       └── app/
│           └── page.sql        ← routeur top-level
├── demo/
│   ├── docker-compose.yml      ← postgres + postgrest + nginx
│   ├── init/
│   └── frontend/
│       └── index.html          ← shell SPA (~40 lignes)
├── .mcp.json                   ← config workbench
└── CLAUDE.md
```

## 7. pgView Primitives — Bibliothèque UI

### Principe

Pas un framework, pas de métadonnées. Juste des **fonctions SQL composables** qui encapsulent les patterns HTML récurrents. Le LLM (ou le dev) les assemble au lieu de réécrire du `format()` à chaque page.

3 niveaux :
```
Atomes      esc, pgv_badge, pgv_money       Formatage pur, IMMUTABLE
Molécules   pgv_page, pgv_card, pgv_table   Structure, composent les atomes
Pages       pgv_dashboard, pgv_products     Assemblent les molécules + queries
```

### Atomes (existants)

```sql
-- Sécurité
esc(text) → text                          -- HTML escape (XSS)

-- Formatage
pgv_badge(text, variant) → text           -- <span> coloré (success/danger/warning/info/gold/silver...)
pgv_money(numeric) → text                 -- $1,299.00
pgv_status(status) → text                 -- badge adapté au statut commande
pgv_tier(tier) → text                     -- badge adapté au tier client
```

### Molécules (à créer — schéma `pgv`)

Les molécules vivent dans un schéma `pgv` dédié, réutilisable par toute app pgView.

#### Layout

```sql
-- Page complète : nav + container + contenu
pgv.page(p_title text, p_path text, p_nav_items jsonb, p_body text) → text

-- Exemple :
SELECT pgv.page('Clients', '/clients',
  '[{"href":"/","label":"Dashboard"},{"href":"/clients","label":"Clients"}]',
  pgv.card('Liste', v_table)
);

-- Résultat :
-- <nav>...</nav>
-- <main class="container">
--   <hgroup><h2>Clients</h2></hgroup>
--   {p_body}
-- </main>
```

```sql
-- Card : article avec header optionnel et footer optionnel
pgv.card(p_title text, p_body text, p_footer text DEFAULT NULL) → text

-- Résultat :
-- <article>
--   <header>p_title</header>
--   p_body
--   <footer>p_footer</footer>   (si non NULL)
-- </article>
```

```sql
-- Grid : disposition en colonnes (PicoCSS grid)
pgv.grid(VARIADIC p_items text[]) → text

-- pgv.grid(pgv.card('A','...'), pgv.card('B','...'), pgv.card('C','...'))
-- → <div class="grid"> {item1} {item2} {item3} </div>
```

#### Données

```sql
-- Table Markdown depuis un curseur/query
-- Génère le <md> avec header + rows automatiquement
pgv.md_table(p_headers text[], p_rows text[][]) → text

-- Exemple :
SELECT pgv.md_table(
  ARRAY['Nom', 'Prix', 'Stock'],
  ARRAY[
    ARRAY['<a href="/products/1">Fumoir A</a>', pgv_money(299), pgv_badge('12','success')],
    ARRAY['<a href="/products/2">Fumoir B</a>', pgv_money(499), pgv_badge('0','danger')]
  ]
);
-- → <figure><md>| Nom | Prix | Stock |
-- | --- | --- | --- |
-- | <a href="...">Fumoir A</a> | $299.00 | <span...>12</span> |
-- | ...</md></figure>
```

```sql
-- Liste clé-valeur (fiche détail)
pgv.dl(VARIADIC p_pairs text[]) → text

-- pgv.dl('Client', 'Marie Dupont', 'Email', 'marie@example.com', 'Tier', pgv_tier('gold'))
-- → <dl><dt>Client</dt><dd>Marie Dupont</dd><dt>Email</dt>...</dl>
```

```sql
-- KPI stat card (pour dashboards)
pgv.stat(p_label text, p_value text, p_detail text DEFAULT NULL) → text

-- pgv.stat('Revenu', pgv_money(12500), '+12% ce mois')
-- → <article><header>Revenu</header><p style="font-size:2rem">$12,500.00</p>
--   <small>+12% ce mois</small></article>
```

#### Formulaires

```sql
-- Formulaire complet
pgv.form(p_action text, p_method text, VARIADIC p_fields text[]) → text

-- pgv.form('/clients', 'POST',
--   pgv.input('name', 'text', 'Nom', required => true),
--   pgv.input('email', 'email', 'Email'),
--   pgv.select('tier', 'Tier', '["bronze","silver","gold"]')
-- )
-- → <form onsubmit="post('/clients', Object.fromEntries(new FormData(this))); return false;">
--   <label>Nom <input name="name" type="text" required></label>
--   <label>Email <input name="email" type="email"></label>
--   <label>Tier <select name="tier"><option>bronze</option>...</select></label>
--   <button type="submit">Envoyer</button>
-- </form>
```

```sql
-- Champ de formulaire
pgv.input(p_name text, p_type text, p_label text,
           p_value text DEFAULT NULL, p_required boolean DEFAULT false) → text

-- Champ select/dropdown
pgv.select(p_name text, p_label text, p_options jsonb,
            p_selected text DEFAULT NULL) → text
```

#### Navigation

```sql
-- Navigation dynamique avec burger menu optionnel
pgv.nav(p_brand text, p_items jsonb, p_current text, p_options jsonb DEFAULT '{}') -> text

-- pgv.nav('Mon ERP',
--   '[{"href":"/","label":"Dashboard"},{"href":"/clients","label":"Clients"}]',
--   '/clients',
--   '{"burger": true}')
```

```sql
-- Breadcrumb
pgv.breadcrumb(VARIADIC p_parts text[]) → text

-- pgv.breadcrumb('/clients', 'Clients', '/clients/42', 'Marie Dupont')
-- → <nav aria-label="breadcrumb"><ul>
--   <li><a href="/clients">Clients</a></li>
--   <li>Marie Dupont</li></ul></nav>
```

```sql
-- Bouton d'action POST via data-rpc
pgv.action(p_endpoint text, p_label text, p_variant text DEFAULT 'primary',
           p_params text DEFAULT '{}', p_confirm text DEFAULT NULL) -> text

-- pgv.action('page', 'Annuler', 'danger',
--   '{"p_path":"/cancel","p_method":"POST","id":"42"}',
--   'Confirmer l''annulation ?')
-- -> <button data-rpc="page" data-params='...' data-confirm="..." class="secondary">Annuler</button>
```

### Composition

Avec ces primitives, une page CRUD complete :

```sql
-- Fonction page : retourne juste le body HTML
-- Le routeur pgv.route() emballe dans pgv.page() avec nav + titre
CREATE FUNCTION clients.get_index() RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  v_rows text[][] := '{}';
  r record;
BEGIN
  FOR r IN SELECT id, name, email, tier FROM clients.clients ORDER BY name
  LOOP
    v_rows := v_rows || ARRAY[ARRAY[
      format('<a href="%s">%s</a>', pgv.href('/client?id=' || r.id), pgv.esc(r.name)),
      pgv.esc(r.email),
      pgv.badge(r.tier, 'gold')
    ]];
  END LOOP;

  RETURN pgv.card('Liste des clients',
    pgv.md_table(ARRAY['Nom','Email','Tier'], v_rows)
  );
END;
$$;
```

Note : la fonction retourne le **body** uniquement. Le routeur `pgv.route()` l'emballe dans `pgv.page()` (nav + titre + layout) automatiquement.

vs **sans primitives** : ~40 lignes de `format()` et concatenation HTML.

### Primitives = plateforme

Le schema `pgv` est **reutilisable entre modules et apps**. Chaque module utilise les memes primitives. `pgv` est distribue via `pgm install`.

## 8. Conventions

### Nommage routes (URL)

```
GET  /                     -> get_index()
GET  /drawings             -> get_drawings()
GET  /drawing?id=42        -> get_drawing(p_id integer)
POST /save                 -> post_save(p_params jsonb)
POST /delete               -> post_delete(p_id integer)
GET  /settings             -> get_settings()
POST /settings             -> post_settings(p_params jsonb)
```

Les parametres dynamiques passent par query string (`?id=42`), pas par segments de path (`/drawing/42`).

### Nommage fonctions

```
{schema}.get_*()           -> pages GET (retournent du body HTML)
{schema}.post_*()          -> actions POST (retournent toast/redirect)
{schema}.nav_items()       -> items de navigation (jsonb)
{schema}.brand()           -> nom du module (text)
{schema}.nav_options()     -> options nav (jsonb, optionnel)
pgv.*()                    -> primitives UI partagees
```

### Schemas DB

```
<domaine>      -- tables + get_*/post_* + nav_items() + brand()
<domaine>_ut   -- tests unitaires du domaine
<domaine>_it   -- tests d'integration (optionnel, run manuel)
pgv            -- primitives UI, routeur, shell (plateforme, ne pas modifier)
pgv_ut         -- tests pgv
```

### Reponses POST

Les fonctions `post_*` retournent des templates interpretes par le shell :

```sql
-- Succes avec redirect
RETURN '<template data-toast="success">Enregistre</template>'
    || '<template data-redirect="/drawings"></template>';

-- Erreur metier
RAISE EXCEPTION 'Champ obligatoire manquant';
-- Le routeur attrape et retourne: <template data-toast="error">...</template>
```

## 9. Sécurité

### Auth (optionnel, v2)

Le routeur peut vérifier un token JWT dans le body ou via PostgREST claims :

```sql
-- Dans le routeur, avant le dispatch
v_role := current_setting('request.jwt.claims', true)::jsonb->>'role';
IF v_role IS NULL AND p_path NOT LIKE '/public/%' THEN
  RETURN err_response('UNAUTHORIZED', 'authentication required');
END IF;
```

### RLS

PostgreSQL Row Level Security pour le contrôle d'accès fin :

```sql
ALTER TABLE app.clients ENABLE ROW LEVEL SECURITY;
CREATE POLICY clients_owner ON app.clients
  USING (owner_id = current_setting('app.user_id')::integer);
```

## 10. Markdown Hybride

### Principe

Les tables sont générées en Markdown dans les fonctions PL/pgSQL, converties côté client par `marked.js`. L'HTML reste pour la structure (nav, cards, formulaires).

```sql
-- Avant (HTML verbose) :
v_html := v_html || '<figure><table><thead><tr>';
v_html := v_html || '<th>Name</th><th>Price</th>';
v_html := v_html || '</tr></thead><tbody>';
FOR r IN SELECT * FROM products LOOP
  v_html := v_html || format('<tr><td>%s</td><td>%s</td></tr>', ...);
END LOOP;
v_html := v_html || '</tbody></table></figure>';

-- Après (Markdown) :
v_md := E'| Name | Price |\n| --- | --- |\n';
FOR r IN SELECT * FROM products LOOP
  v_md := v_md || format(E'| <a href="/products/%s">%s</a> | %s |\n', ...);
END LOOP;
v_html := v_html || '<figure><md>' || v_md || '</md></figure>';
```

### Shell SPA

Le shell Alpine.js (`index.html`) convertit les `<md>` via `_enhance()` :

```js
// _enhance() runs after each page render
el.querySelectorAll('md').forEach(function(md) {
  var pageSize = parseInt(md.dataset.page) || 0;
  var div = document.createElement('div');
  div.innerHTML = marked.parse(md.innerHTML.trim());
  // Tables get automatic sort + pagination
  div.querySelectorAll('table').forEach(function(tbl) {
    var wrap = document.createElement('div');
    wrap.className = 'pgv-table';
    tbl.parentNode.insertBefore(wrap, tbl);
    wrap.appendChild(tbl);
    self._initTable(wrap, tbl, pageSize);
  });
  md.parentNode.replaceChild(div, md);
});

// Make rows with internal links clickable
el.querySelectorAll('tbody tr').forEach(function(tr) {
  var a = tr.querySelector('a[href^="/"]');
  if (!a) return;
  tr.style.cursor = 'pointer';
  tr.addEventListener('click', function(e) {
    if (e.target.closest('a, button')) return;
    self.go(a.getAttribute('href'));
  });
});
```

### Quand utiliser quoi

| Contenu | Rendu |
|---------|-------|
| Tables de données | `<md>` Markdown |
| Navigation | HTML (nav, links) |
| Cards, stats | HTML (article, dl) |
| Formulaires | HTML (form, input) |
| Badges, money | HTML inline dans Markdown (`pgv_badge()`, `pgv_money()`) |
| Graphes | HTML + `<script>` Mermaid.js |

## 11. Extensions PostgreSQL Recommandées

### Installées

| Extension | Usage |
|-----------|-------|
| `plpgsql_check` | Validation statique des fonctions PL/pgSQL au deploy |
| `pgtap` | Tests unitaires en SQL |

### Recommandées — v1

| Extension | Usage |
|-----------|-------|
| `pg_trgm` | Recherche fuzzy avec index GIN |
| `pgcrypto` | Hash passwords, `gen_random_uuid()` |

### Recommandées — v2

| Extension | Usage |
|-----------|-------|
| `pg_cron` | Jobs planifiés (purge, stats, maintenance) |
| `pg_net` | HTTP async depuis triggers (webhooks, emails) |
| `supa_audit` | Audit trail automatique par table |
| `pg_jsonschema` | Validation JSON Schema en CHECK constraint |

### Nice to have

| Extension / Service | Usage |
|---------------------|-------|
| `index_advisor` | Recommandation d'index automatique |
| `pg_hashids` | URLs courtes non séquentielles |
| `pg_eventserv` | Temps réel (LISTEN/NOTIFY → WebSocket) |

## 12. Déploiement Supabase

### Ce qui fonctionne

- Toutes les fonctions PL/pgSQL et SQL
- PostgREST intégré (`POST /rest/v1/rpc/page`)
- Auth (JWT), RLS, Storage
- Extensions : plpgsql_check, pgTAP, pg_trgm, pgcrypto, pg_net, supa_audit

### Adaptation requise

```js
// pgview.html — changer l'API endpoint
var API = 'https://<project>.supabase.co/rest/v1/rpc/page';

// Ajouter le header apikey dans fetch
headers: {
  'Content-Type': 'application/json',
  'apikey': '<anon-key>'
}
```

### Ce qui ne fonctionne pas

- `pldebugger` (pldbgapi) — pas disponible sur Supabase
- Extensions custom hors catalogue
- `shared_preload_libraries` custom

### Coût

- Free : 500 MB DB, 2 projets, pause après 7j inactivité
- Pro : 25$/mois, 8 GB DB, pas de pause, backups quotidiens
- Multi-tenant RLS : 1 projet Pro pour N clients

## Resume

Un pattern complet pour construire des apps avec PostgreSQL :
- **Router pgv.route()** — generique, zero config, pg_proc introspection
- **get_/post_ convention** — une fonction = une page ou action, pas de CASE a maintenir
- **pgView** — SSR en PL/pgSQL, Markdown hybride, hot reload instantane
- **Alpine.js shell** — SPA legere, data-* contract, toast/redirect, tables triables
- **Schema = Module** — DDD dans PostgreSQL, bounded contexts isoles
- **PostgREST** — transport HTTP, zero code
- **Extension VS Code** — UI generique qui suit les liens (alternative a pgView)
- **MCP Workbench** — boucle de dev (pg_func_set -> pg_test -> pg_pack)
- **Meme DB, memes fonctions, memes URIs** — une seule source de verite

Voir aussi :
- [FRONTEND.md](FRONTEND.md) — reference complete du shell Alpine.js, data-* contract, CSS
- [BUSINESS.md](BUSINESS.md) — business plan et projections financieres
- [AI-INTEGRATION.md](AI-INTEGRATION.md) — integration LLM, chat widget, agent autonome
