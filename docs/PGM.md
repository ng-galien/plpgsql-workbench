# pgm — PostgreSQL Module Manager

Gestionnaire de modules pour applications PostgreSQL. Inspiré de npm : manifests déclaratifs, résolution de dépendances, déploiement avec vérification.

## Installation

```bash
npm run build          # compile src/pgm/ → dist/pgm/
npm link               # rend `pgm` disponible globalement
```

Ou sans link : `node dist/pgm/cli.js <commande>`

## Commandes

Le CLI est organisé en deux groupes : **app** (lifecycle d'une application) et **module** (développement de modules).

### pgm app init

Initialise une nouvelle app dans le dossier courant. Auto-assigne les ports en scannant les apps existantes.

```bash
mkdir apps/billing && cd apps/billing
pgm app init
# Initializing app billing...
#   ports: PG=5445 PostgREST=3005 HTTP=8085 MCP=3105
#   workbench.json
#   docker-compose.yml
#   Makefile
#   sql/01-roles.sql
#   frontend/nginx.conf
#   .mcp.json                    ← MCP → app server (port MCP)
#   .claude/settings.local.json  ← permissions app + hooks
```

### pgm app install

Copie les fichiers SQL, assets, scripts et styles des modules dans le dossier de l'app. Génère `pgv-modules.js` pour le chargement des composants Alpine.js.

```bash
pgm app install              # installe tous les modules de workbench.json
pgm app install cad        # ajoute cad à workbench.json + installe
pgm app install -d           # installe + dry run du déploiement
pgm app install -d --apply   # installe + déploie en base
```

### pgm app deploy

Vérifie les dépendances en base et applique le SQL. Dry run par défaut.

```bash
pgm app deploy               # dry run : plan + check extensions/schemas
pgm app deploy cad         # dry run pour un seul module
pgm app deploy --apply       # vérifie puis exécute le SQL
pgm app deploy cad --apply # vérifie puis exécute un seul module
```

Le check vérifie :
- **Extensions** — les extensions requises existent dans `pg_extension`
- **Schemas** — les schemas des dépendances existent dans `pg_namespace`

Si une dépendance manque, le déploiement est bloqué.

### pgm app list

Affiche l'arbre des modules installés dans l'app courante.

```bash
pgm app list
# cad
# ├── pgv@1.0.0
# └── cad@0.1.0 (needs: pgv)
```

### pgm app remove

Retire un module de workbench.json.

```bash
pgm app remove cad
# Removed "cad" from workbench.json
# Run 'pgm app install' to re-sync files
```

### pgm module new

Scaffold un nouveau module dans `modules/`.

```bash
pgm module new billing
# Creating module billing...
#   module.json
#   sql/functions.sql
#   .mcp.json                    ← MCP → dev server (port 3100)
#   .claude/settings.local.json  ← permissions dev (pg_func_set, pg_pack, pg_test...)
```

Le module généré :
- Dépend de `pgv` par défaut
- `.mcp.json` pointe vers le serveur dev (port 3100, dev DB sur 5433)
- `.claude/settings.local.json` inclut les tools de développement (pas de docker, pas de deploy)
- Option `--schema <name>` pour un nom de schema différent du nom du module

### pgm module info

Affiche les détails d'un module.

```bash
pgm module info cad
# cad@0.1.0
#   CAD 3D engine for wood structures...
#   schemas:
#     public:  cad
#     private: _cad
#   dependencies: pgv
#   extensions: postgis, postgis_sfcgal
#   sql: sql/extensions.sql, sql/ddl.sql, sql/functions.sql
#   scripts: frontend/cad.js
#   styles: frontend/cad.css
#   docker: postgis/postgis:17-3.5
```

### pgm module list

Liste tous les modules disponibles dans le workspace.

```bash
pgm module list
#   cad@0.1.0  CAD 3D engine for wood structures...
#   pgv@1.0.0    pgView — Server-Side Rendering framework...
```

## Concepts

### Module

Un module est un dossier dans `modules/` contenant un `module.json` et ses fichiers source :

```
modules/
  pgv/
    module.json
    sql/
      00-extensions.sql
      functions.sql
    frontend/
      index.html
      pgview.css
  cad/
    module.json
    sql/
      extensions.sql
      ddl.sql
      functions.sql
      cad/              ← pg_func_save individuel
        add_beam.sql
        ...
    frontend/
      viewer.html
      cad.js          ← Alpine.js components
      cad.css          ← module styles
```

### module.json

Manifeste déclaratif d'un module :

```json
{
  "name": "cad",
  "version": "0.1.0",
  "description": "CAD 3D engine for wood structures.",
  "schemas": {
    "public": "cad",
    "private": "_cad"
  },
  "dependencies": ["pgv"],
  "extensions": ["postgis", "postgis_sfcgal"],
  "sql": [
    "sql/extensions.sql",
    "sql/ddl.sql",
    "sql/functions.sql"
  ],
  "assets": {
    "frontend": ["frontend/viewer.html"],
    "scripts": ["frontend/cad.js"],
    "styles": ["frontend/cad.css"]
  },
  "grants": {
    "anon": ["cad"]
  },
  "docker": {
    "image": "postgis/postgis:17-3.5",
    "note": "Requires PostGIS image (not supabase/postgres)"
  }
}
```

| Champ | Description |
|-------|-------------|
| `name` | Identifiant unique du module |
| `version` | Version semver |
| `schemas.public` | Schema accessible via PostgREST (GRANT anon) |
| `schemas.private` | Schema interne (pas de GRANT externe) |
| `dependencies` | Modules requis (installés/déployés avant) |
| `extensions` | Extensions PostgreSQL requises |
| `sql` | Fichiers SQL à déployer, dans l'ordre |
| `assets.frontend` | Fichiers copiés dans `frontend/` de l'app |
| `assets.scripts` | JS chargés par le shell (composants Alpine.js) |
| `assets.styles` | CSS chargés par le shell (styles du module) |
| `grants` | Rôles et schemas pour GRANT automatique |
| `docker` | Image Docker requise (si différente du défaut) |

### Application

Une application vit dans `apps/` et déclare ses modules dans `workbench.json` :

```json
{
  "name": "cad",
  "packs": ["plpgsql"],
  "modules": ["pgv", "cad"],
  "connection": "postgresql://postgres:postgres@localhost:5444/postgres",
  "port": 3104
}
```

### Résolution de dépendances

pgm résout les dépendances par tri topologique (algorithme de Kahn) :

```
workbench.json: modules: ["cad"]
  → cad dépend de pgv
  → ordre d'installation/déploiement : pgv → cad
```

Si un module échoue au déploiement, les modules qui en dépendent ne sont pas exécutés.

### Convention de nommage SQL

Quand pgm installe les fichiers SQL dans une app, il les préfixe avec un slot :

| Slot | Source | Contenu |
|------|--------|---------|
| `00` | pgv | Extensions de base (plpgsql_check, pgtap) |
| `01` | app | Rôles et permissions (jamais dans un module) |
| `02` | pgv | Framework pgv (schemas pgv + pgv_ut) |
| `05` | module N | Extensions + DDL + fonctions du module |
| `06` | module N+1 | Module suivant |

Les fichiers d'un module sont nommés `{slot}-{module}-{basename}.sql`.

Exemple pour l'app CAD :
```
sql/
  00-extensions.sql          ← pgv
  01-roles.sql               ← app
  02-pgv.sql                 ← pgv
  05-cad-extensions.sql    ← cad
  05-cad-ddl.sql           ← cad
  05-cad-functions.sql     ← cad
  05-groups.sql              ← app
```

## Module registry — MCP tools auto-path

Le serveur MCP est **module-aware** : les tools `pg_pack` et `pg_func_save` n'ont plus besoin de path. Un **module registry** mappe chaque schema à son module via les fichiers `module.json`.

### Comment ça marche

Au démarrage, le MCP server :
1. Trouve le workspace root (remonte jusqu'à trouver `modules/`)
2. Scanne tous les `modules/*/module.json`
3. Construit un mapping `schema → module → paths`

Quand un tool est appelé :
- `pg_pack schemas: "cad,cad_ut"` → le registry résout : schema `cad` → module `cad` → `modules/cad/sql/functions.sql`
- `pg_func_save target: "plpgsql://cad"` → le registry résout : schema `cad` → module `cad` → `modules/cad/sql/`

### pg_pack (module-aware)

Exporte les fonctions d'un ou plusieurs schemas dans le fichier `functions.sql` du module correspondant.

```
pg_pack schemas: "cad,cad_ut"
# → packed 54 functions from 2 schema(s) -> cad/sql/functions.sql
# → deps: 35 edges resolved via AST
```

Plus de paramètre `path`. Le registry sait que `cad` + `cad_ut` appartiennent au module `cad` et écrit dans `modules/cad/sql/functions.sql`.

Si les schemas ne correspondent à aucun module :
```
# → problem: no module owns schemas [foo, foo_ut]
# → fix_hint: check modules/*/module.json schemas field
```

### pg_func_save (module-aware)

Sauvegarde les fonctions individuelles dans le dossier SQL du module.

```
pg_func_save target: "plpgsql://cad"
# → dumped 49 functions to modules/cad/sql/cad/
```

Plus de paramètre `path`. Le registry résout `cad` → `modules/cad/sql/`.

### Mapping des schemas

Le registry inclut automatiquement les schemas de test par convention :

| Schema dans module.json | Schemas reconnus |
|------------------------|------------------|
| `schemas.public: "cad"` | `cad`, `cad_ut`, `cad_it` |
| `schemas.private: "_cad"` | `_cad` |

## Fragments — Composants Alpine.js

Les modules peuvent fournir des **fragments** : des composants Alpine.js réutilisables dans n'importe quelle page PL/pgSQL.

### Comment ça marche

```
module.json                      pgv-modules.js            Alpine.js
  assets.scripts: [cad.js]  →    <script src=cad.js>  →  Alpine.data('cadViewer')
  assets.styles: [cad.css]  →    <link href=cad.css>

PL/pgSQL fragment                 Shell _enhance()
  cad.fragment_viewer(id)     →    Alpine.initTree(el)    →  x-data="cadViewer" activé
```

1. **module.json** déclare `assets.scripts` et `assets.styles`
2. **pgm install** copie les fichiers et génère `pgv-modules.js`
3. **Le shell** charge `pgv-modules.js` avant Alpine.js → composants enregistrés
4. **PL/pgSQL** génère du HTML avec `x-data="composant"` → Alpine l'active via `initTree()`

### Exemple

Module JS (`frontend/cad.js`) :
```js
document.addEventListener('alpine:init', function() {
  Alpine.data('cadViewer', function() {
    return {
      drawingId: null,
      load: function(id) { /* Three.js setup, fetch scene... */ },
      resetCamera: function() { /* ... */ },
      toggleWireframe: function() { /* ... */ }
    };
  });
});
```

Fragment PL/pgSQL :
```sql
CREATE FUNCTION cad.fragment_viewer(p_drawing_id int)
RETURNS text LANGUAGE sql AS $$
  SELECT '<div x-data="cadViewer" x-init="load(' || p_drawing_id || ')">'
      || '  <canvas x-ref="viewport"></canvas>'
      || '  <button @click="resetCamera()">Reset</button>'
      || '</div>';
$$;
```

Utilisation dans une page :
```sql
v_body := '<div class="grid">'
       || cad.fragment_viewer(p_id)
       || cad.fragment_tree(p_id)
       || '</div>';
```

### pgv-modules.js

Fichier auto-généré par `pgm install`. Charge les scripts et styles de tous les modules :

```js
// Auto-generated by pgm install — DO NOT EDIT
(function() {
  var l = document.createElement('link');
  l.rel = 'stylesheet'; l.href = '/cad.css';
  document.head.appendChild(l);
  var s = document.createElement('script');
  s.src = '/cad.js';
  document.head.appendChild(s);
})();
```

Le shell `index.html` le charge avant Alpine.js :
```html
<script src="/pgv-modules.js"></script>
<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3/dist/cdn.min.js"></script>
```

## Workflow

### Créer un module

```bash
pgm module new billing           # scaffold dans modules/billing/
pgm module new billing -s bill   # schema "bill" au lieu de "billing"
# → module.json, sql/functions.sql, .mcp.json (dev), .claude/settings.local.json (dev)
```

Puis itérer avec le MCP workbench (connecté à la dev DB, port 5433) :

```bash
# L'agent Claude Code utilise les MCP tools :
pg_func_set ...          # créer/modifier des fonctions
pg_test ...              # valider

# Exporter (auto-résolu via module registry) :
pg_pack schemas: "billing,billing_ut"   # → modules/billing/sql/functions.sql
pg_func_save target: "plpgsql://billing" # → modules/billing/sql/billing/*.sql
```

### Créer une app

```bash
mkdir apps/billing && cd apps/billing
pgm app init                 # scaffold + ports auto
pgm app install cad        # ajoute un module
make up                      # démarre postgres + postgrest + nginx
pgm app deploy               # dry run (check deps en base)
pgm app deploy --apply       # applique le SQL
```

### Pipeline complet

```
pgm module new       scaffold module (module.json, .mcp.json dev, .claude)
      ↓
pg_func_set          dev itératif dans la dev DB (MCP tools)
pg_test              validation pgTAP
      ↓
pg_pack              auto → modules/{mod}/sql/functions.sql
pg_func_save         auto → modules/{mod}/sql/{schema}/*.sql
      ↓
pgm app install      modules/ → apps/*/sql/ + frontend/
      ↓
pgm app deploy       SQL → DB live (en ordre de deps, --apply)
```

Impossible de sauver au mauvais endroit : les tools MCP connaissent le module registry et résolvent automatiquement le chemin de sortie.

### Contextes MCP

| Contexte | `.mcp.json` pointe vers | DB | Cas d'usage |
|----------|------------------------|----|-------------|
| Module (`modules/cad/`) | dev server (port 3100) | dev DB (5433) | Développement itératif |
| App (`apps/004-cad/`) | app server (port 3104) | app DB (5444) | Intégration, déploiement |

Chaque contexte a ses propres permissions Claude Code (`.claude/settings.local.json`) :
- **Module** : tools dev (pg_func_set, pg_pack, pg_test, pg_doc...), pas de docker/deploy
- **App** : tools app (pg_query, pg_schema, pg_pack...) + docker compose + hooks

## Architecture

```
src/pgm/
  cli.ts          # Entry point CLI (pgm app ..., pgm module ...)
  resolver.ts     # Lecture module.json, résolution deps (topo sort)
  installer.ts    # Copie fichiers + génération pgv-modules.js
  deployer.ts     # Check deps en base + exécution SQL
  scaffold.ts     # Génération fichiers app + module
  registry.ts     # Mapping schema → module (injecté dans MCP tools)
```
