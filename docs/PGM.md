# pgm — PostgreSQL Module Manager

Gestionnaire de modules pour applications PostgreSQL. Inspiré de npm : manifests déclaratifs, résolution de dépendances, déploiement avec vérification.

## Installation

```bash
npm run build          # compile src/pgm/ → dist/pgm/
npm link               # rend `pgm` disponible globalement
```

Ou sans link : `node dist/pgm/cli.js <commande>`

## Commandes

### pgm init

Initialise une nouvelle app dans le dossier courant. Auto-assigne les ports en scannant les apps existantes.

```bash
mkdir apps/billing && cd apps/billing
pgm init
# Initializing billing...
#   ports: PG=5445 PostgREST=3005 HTTP=8085 MCP=3105
#   workbench.json
#   docker-compose.yml
#   Makefile
#   sql/01-roles.sql
#   frontend/nginx.conf
#   .mcp.json
#   .claude/settings.local.json
```

Fichiers générés :
- `workbench.json` — config app avec modules `["pgv"]` par défaut
- `docker-compose.yml` — postgres + postgrest + nginx
- `Makefile` — targets up/down/clean/sync/mcp
- `sql/01-roles.sql` — roles, domain text/html, schemas
- `frontend/nginx.conf` — proxy PostgREST + MCP
- `.mcp.json` — config MCP pour Claude Code
- `.claude/settings.local.json` — permissions + hooks

### pgm install

Copie les fichiers SQL et assets des modules dans le dossier de l'app.

```bash
pgm install              # installe tous les modules de workbench.json
pgm install cad3d        # ajoute cad3d à workbench.json + installe
pgm install -d           # installe + dry run du déploiement
pgm install -d --apply   # installe + déploie en base
```

### pgm deploy

Vérifie les dépendances en base et applique le SQL. Dry run par défaut.

```bash
pgm deploy               # dry run : plan + check extensions/schemas
pgm deploy cad3d         # dry run pour un seul module
pgm deploy --apply       # vérifie puis exécute le SQL
pgm deploy cad3d --apply # vérifie puis exécute un seul module
```

Le check vérifie :
- **Extensions** — les extensions requises existent dans `pg_extension`
- **Schemas** — les schemas des dépendances existent dans `pg_namespace`

Si une dépendance manque, le déploiement est bloqué.

### pgm list

Affiche l'arbre des modules installés.

```bash
pgm list
# cad
# ├── pgv@1.0.0
# └── cad3d@0.1.0 (needs: pgv)
```

### pgm info

Affiche les détails d'un module.

```bash
pgm info cad3d
# cad3d@0.1.0
#   CAD 3D engine for wood structures...
#   schemas:
#     public:  cad
#     private: _cad
#   dependencies: pgv
#   extensions: postgis, postgis_sfcgal
#   sql: sql/extensions.sql, sql/ddl.sql, sql/functions.sql
#   assets: frontend/viewer.html
#   docker: postgis/postgis:17-3.5
```

### pgm available

Liste tous les modules disponibles dans le workspace.

```bash
pgm available
#   cad3d@0.1.0  CAD 3D engine for wood structures...
#   pgv@1.0.0    pgView — Server-Side Rendering framework...
```

### pgm remove

Retire un module de workbench.json.

```bash
pgm remove cad3d
# Removed "cad3d" from workbench.json
# Run 'pgm install' to re-sync files
```

### pgm pack

Indique la commande pg_pack équivalente pour exporter les fonctions d'un module depuis la DB.

```bash
pgm pack cad,cad_ut -m cad3d
# pg_pack equivalent:
#   schemas: cad,cad_ut
#   path: modules/cad3d/sql/functions.sql
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
      pgv.sql
    frontend/
      index.html
      pgview.css
  cad3d/
    module.json
    sql/
      extensions.sql
      ddl.sql
      functions.sql
    frontend/
      viewer.html
```

### module.json

Manifeste déclaratif d'un module :

```json
{
  "name": "cad3d",
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
    "frontend": ["frontend/viewer.html"]
  },
  "grants": {
    "web_anon": ["cad"]
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
| `schemas.public` | Schema accessible via PostgREST (GRANT web_anon) |
| `schemas.private` | Schema interne (pas de GRANT externe) |
| `dependencies` | Modules requis (installés/déployés avant) |
| `extensions` | Extensions PostgreSQL requises |
| `sql` | Fichiers SQL à déployer, dans l'ordre |
| `assets.frontend` | Fichiers copiés dans `frontend/` de l'app |
| `grants` | Rôles et schemas pour GRANT automatique |
| `docker` | Image Docker requise (si différente du défaut) |

### Application

Une application vit dans `apps/` et déclare ses modules dans `workbench.json` :

```json
{
  "name": "cad",
  "packs": ["plpgsql"],
  "modules": ["pgv", "cad3d"],
  "connection": "postgresql://postgres:postgres@localhost:5444/postgres",
  "port": 3104
}
```

### Résolution de dépendances

pgm résout les dépendances par tri topologique (algorithme de Kahn) :

```
workbench.json: modules: ["cad3d"]
  → cad3d dépend de pgv
  → ordre d'installation/déploiement : pgv → cad3d
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
  05-cad3d-extensions.sql    ← cad3d
  05-cad3d-ddl.sql           ← cad3d
  05-cad3d-functions.sql     ← cad3d
  05-groups.sql              ← app
```

## Workflow

### Créer une app

```bash
mkdir apps/billing && cd apps/billing
pgm init                 # scaffold + ports auto
pgm install cad3d        # ajoute un module
make up                  # démarre postgres + postgrest + nginx
pgm deploy               # dry run (check deps en base)
pgm deploy --apply       # applique le SQL
```

### Développer

```bash
# 1. Itérer avec le MCP workbench
pg_func_set ...          # créer/modifier des fonctions
pg_test ...              # valider

# 2. Exporter dans le module source
pgm pack cad,cad_ut -m cad3d

# 3. Distribuer aux apps
pgm install              # sync fichiers module → app
pgm deploy --apply       # appliquer en base
```

### Depuis un dossier d'app

pgm détecte le contexte en remontant l'arborescence :

```bash
cd apps/billing
pgm list                 # trouve workbench.json → app root
                         # remonte pour trouver modules/ → workspace root
```

### Makefile

Chaque app a un target `sync` qui appelle pgm :

```makefile
sync:
    node ../../dist/pgm/cli.js install
```

Au niveau root :

```makefile
sync-modules:
    @for app in apps/*/; do \
        (cd "$$app" && node ../../dist/pgm/cli.js install) || true; \
    done
```

## Architecture

```
src/pgm/
  cli.ts          # Entry point (commander.js)
  resolver.ts     # Lecture module.json, résolution deps (topo sort)
  installer.ts    # Copie fichiers avec slot assignment
  deployer.ts     # Check deps en base + exécution SQL
  scaffold.ts     # Génération fichiers app (pgm init)
```
