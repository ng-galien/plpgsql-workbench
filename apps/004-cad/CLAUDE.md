# CAD 2D — Plans de structures bois

Application de dessin technique 2D pour plans de petites structures en bois (fumoirs, abris, ateliers). Utilisable aussi pour des plans d'artisans (aménagement boutique, atelier, implantation machines).

## Stack

- **PostgreSQL** — stockage des dessins + calculs géométriques (types natifs: point, lseg, box, path, polygon, circle)
- **PL/pgSQL** — toute la logique métier + rendu SVG
- **PostgREST** — API REST automatique (port 3004)
- **pgView + htmx** — frontend SSR généré par PostgreSQL (port 8084)
- **MCP workbench** — outil de dev (port 3104)

## Infra

```bash
make up          # DB:5444 + PostgREST:3004 + Frontend:8084
make mcp         # MCP workbench sur :3104 (auto-reload)
make down        # Stop
make clean       # Stop + wipe data
```

## Workflow de dev

1. **DDL** (schemas, tables, indexes) -> fichiers SQL dans `sql/` -> `make clean && make up` pour recharger
2. **Fonctions PL/pgSQL** -> `pg_func_set` pour creer/iterer + `pg_test` pour valider
3. **Quand c'est stable** -> `pg_pack` pour exporter les fonctions en fichiers .sql dans `sql/`
4. JAMAIS ecrire des fonctions dans des fichiers SQL directement

## Schema `cad`

### Modele de donnees

- `cad.drawing` — un dessin (nom, echelle, unite mm/cm/m, largeur/hauteur)
- `cad.layer` — calques (nom, couleur, epaisseur trait, visible, locked)
- `cad.shape` — primitives 2D avec geometrie en jsonb

### Types de shapes

| Type | Description | Geometrie jsonb |
|------|-------------|-----------------|
| `line` | Segment | `{x1, y1, x2, y2}` |
| `rect` | Rectangle | `{x, y, w, h, rotation?}` |
| `circle` | Cercle | `{cx, cy, r}` |
| `arc` | Arc | `{cx, cy, r, start_angle, end_angle}` |
| `polyline` | Polyligne | `{points: [[x,y], ...]}` |
| `text` | Texte | `{x, y, content, size, anchor?}` |
| `dimension` | Cote | `{x1, y1, x2, y2, offset}` |

### Attributs bois (jsonb `props`)

Pour les shapes de type structure (line, rect representant poutres/montants):
- `wood_type` — essence (pin, chene, douglas, etc.)
- `section` — section en mm (ex: "45x90", "60x120")
- `role` — montant, traverse, chevron, poteau, lisse, etc.

### Fonctions cles a developper

1. **DDL** (`sql/03-ddl.sql`) — CREATE TABLE + indexes
2. **CRUD** — `cad.add_shape()`, `cad.move_shape()`, `cad.delete_shape()`, `cad.list_shapes()`
3. **Rendu SVG** — `cad.render_svg(drawing_id)` -> `<svg>` complet avec viewBox auto-calcule
4. **Cotes** — `cad.render_dimension()` -> lignes de cote avec texte de la mesure
5. **Liste de debit** — `cad.bill_of_materials(drawing_id)` -> liste des pieces bois avec longueur, section, essence
6. **pgView pages** — `cad.page(path, body)` -> interface web pour visualiser/editer les plans
7. **Tests pgTAP** — `cad_ut.test_*()` pour chaque fonction

### Rendu SVG

Le SVG est genere par PL/pgSQL. Chaque shape se transforme en element SVG:
- `line` -> `<line x1=.. y1=.. x2=.. y2=.. />`
- `rect` -> `<rect x=.. y=.. width=.. height=.. />`
- `circle` -> `<circle cx=.. cy=.. r=.. />`
- `dimension` -> `<line>` + `<text>` avec la mesure calculee
- Calques = `<g>` avec style (couleur, stroke-width)
- viewBox calcule depuis le bounding box de toutes les shapes

### pgView — Interface web

Pages a implementer:
- `/` — liste des dessins
- `/drawing/:id` — vue du plan (SVG interactif via htmx)
- `/drawing/:id/bom` — liste de debit
- `/drawing/:id/edit` — ajout/modif de shapes (formulaires htmx)

Le frontend utilise pgView (PL/pgSQL genere le HTML) + htmx pour l'interactivite.
Le SVG est inline dans la page HTML, cliquable pour selectionner des shapes.

### Calculs PostgreSQL

Exploiter les types geometriques natifs pour:
- Distance entre deux points: `point(x1,y1) <-> point(x2,y2)`
- Bounding box: `min/max` sur les coordonnees
- Surface: calcul depuis les shapes rect/polygon
- Intersection: operateur `#` pour detecter les collisions

## pgView — Regles STRICTES

### INTERDIT
- **NE JAMAIS modifier** le schema `pgv` (fonctions, shell, router, CSS)
- **NE JAMAIS modifier** le fichier `pgv.sql` ou `pgview.css`
- **NE JAMAIS modifier** le fichier `frontend/index.html` (le shell pgView)
- **NE JAMAIS creer** de fichiers JS/CSS custom dans `frontend/`
- **NE JAMAIS contourner** pgv.route en hackant le shell ou PostgREST

### Comment pgv.route fonctionne

`pgv.route(schema, path, body)` derive un nom de fonction depuis le path :
- `/` -> `page_index()`
- `/drawings` -> `page_drawings()`
- `/settings` -> `page_settings()`

Il appelle `schema.page_xxx()` **SANS parametres** (ligne 241 de pgv.sql).
Les pages statiques fonctionnent directement.

### Routes dynamiques (ex: `/drawing/1`)

pgv.route ne gere PAS les routes dynamiques. Pour `/drawing/1` il chercherait `page_drawing_1()`.

**La bonne approche** : `cad.page()` fait son propre dispatching pour les routes dynamiques :

```sql
CREATE OR REPLACE FUNCTION cad.page(p_path text, p_body jsonb DEFAULT '{}')
RETURNS "text/html" LANGUAGE plpgsql AS $$
DECLARE
  v_parts text[];
  v_body text;
BEGIN
  v_parts := string_to_array(trim(BOTH '/' FROM p_path), '/');

  -- Routes dynamiques (avec ID)
  IF v_parts[1] = 'drawing' AND v_parts[2] IS NOT NULL THEN
    v_body := cad.page_drawing_view(v_parts[2]::int, p_body);
    RETURN pgv.route_wrap('cad', p_path, v_body);
  END IF;

  -- Routes statiques -> deleguer a pgv.route
  RETURN pgv.route('cad', p_path, p_body);
END;
$$;
```

Note: `pgv.route_wrap` n'existe pas encore. En attendant, appeler `pgv.page()` directement pour emballer le body dans le layout :
```sql
RETURN pgv.page(cad.brand(), 'Drawing', p_path, cad.nav_items(), v_body);
```

### Formulaires et POST

Le shell pgView envoie TOUS les champs du formulaire comme parametres top-level a PostgREST.
Un `<form data-rpc="page">` avec un champ `name` envoie `{name: "...", p_path: "/..."}`.
PostgREST cherche `cad.page(name, p_path)` -> ERREUR.

**La bonne approche** : les champs du formulaire doivent etre dans `p_body` jsonb.
Utiliser des champs caches ou le pattern htmx `hx-vals` :
```html
<form hx-post="/api/rpc/page" hx-vals='{"p_path": "/drawing/add"}'>
  <input type="hidden" name="p_body" value='{"name": "..."}' />
</form>
```

Ou mieux : utiliser `hx-post` direct avec des endpoints RPC dedies (pas via `page()`).

## Conventions

- Schema principal: `cad`
- Schema tests: `cad_ut`
- Roles: `web_anon` (lecture), `authenticator`
- Toute logique en PL/pgSQL, zero SQL dans le code TypeScript
- Config app dans `workbench.config('cad', key, value)` si besoin
- Les fonctions page sont dans le schema `cad`, pas dans un schema separe
- Le routing dynamique se fait dans `cad.page()`, pas en modifiant pgv
