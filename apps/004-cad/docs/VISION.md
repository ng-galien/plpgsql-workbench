# CAD 3D — Vision technique

## Concept

PostgreSQL + PostGIS/SFCGAL comme **moteur CAD 3D**, piloté par un agent AI via MCP.

L'agent (Claude) ne fait pas des inserts aveugles — il **raisonne** sur le modèle via des requêtes spatiales PostGIS. Chaque `pg_query` lui donne une conscience spatiale : distances, collisions, volumes, connexions entre pièces.

Le browser est la fenêtre de visualisation. PostgreSQL est le cerveau géométrique.

## Pipeline

```
Modélisation        Vérification         Plan de montage       Export
(MCP + PostGIS)     (ST_3DIntersects)    (graphe + SVG)        (BOM + STL)
     │                    │                    │                    │
     ▼                    ▼                    ▼                    ▼
  pg_query            pg_query             pg_query            pg_query
  ST_Extrude          ST_3DIntersects      ST_Translate        ST_3DVolume
  ST_3DDifference     ST_Distance          assembly graph      ST_AsSTL
```

## Stack

| Couche | Techno | Rôle |
|--------|--------|------|
| Stockage | PostGIS `geometry(POLYHEDRALSURFACEZ)` | Géométries 3D natives |
| Calcul | SFCGAL (extrusion, CSG, tesselation) | Moteur géométrique |
| Intelligence | MCP tools + pg_query | Agent raisonne sur le modèle |
| Rendu | Three.js (BufferGeometry + OrbitControls, CDN) | Visualisation 3D live |
| Assemblage | PL/pgSQL + graphe de connexions | Plans de montage SVG |
| Export | ST_AsSTL, bill_of_materials | Fichiers fabrication |

## Modèle de données

### `cad.piece` — pièce de bois

```sql
CREATE TABLE cad.piece (
  id serial PRIMARY KEY,
  drawing_id int NOT NULL REFERENCES cad.drawing(id) ON DELETE CASCADE,
  label text,                          -- "Poteau A1", "Traverse T3"
  role text,                           -- montant, traverse, chevron, lisse
  wood_type text DEFAULT 'pin',        -- essence
  section text NOT NULL,               -- "60x60", "45x90", "60x120"

  -- Géométrie PostGIS
  profile geometry(POLYGONZ, 0),       -- section 2D (le profil à extruder)
  geom geometry(POLYHEDRALSURFACEZ, 0),-- solide 3D (résultat de l'extrusion)

  -- Métadonnées calculées (matérialisées pour perf)
  length_mm real GENERATED ALWAYS AS (ST_ZMax(geom) - ST_ZMin(geom)) STORED,
  volume_mm3 real,                     -- ST_3DVolume(geom), updated by trigger

  created_at timestamptz DEFAULT now()
);
```

### `cad.joint` — connexion entre pièces (vue matérialisée ou table)

```sql
-- Détection automatique des connexions
CREATE VIEW cad.joint AS
SELECT
  a.id AS piece_a,
  b.id AS piece_b,
  a.label AS label_a,
  b.label AS label_b,
  ST_3DIntersection(a.geom, b.geom) AS contact_geom,
  ST_Area(ST_3DIntersection(a.geom, b.geom)) AS contact_area
FROM cad.piece a
JOIN cad.piece b ON a.id < b.id
  AND a.drawing_id = b.drawing_id
  AND ST_3DIntersects(a.geom, b.geom);
```

## Fonctions clés

### Modélisation

```sql
-- Créer une pièce par extrusion d'un profil
cad.add_piece(drawing_id, section, length_mm, position, rotation, label, role, wood_type)
  -- 1. Parse section "60x90" → rectangle 2D
  -- 2. ST_Extrude(profile, dx, dy, dz) selon orientation
  -- 3. ST_Rotate + ST_Translate pour positionner
  -- 4. INSERT avec le solide résultant

-- Déplacer une pièce
cad.move_piece(piece_id, dx, dy, dz)
  -- ST_Translate(geom, dx, dy, dz)

-- Creuser (tenon-mortaise)
cad.subtract_piece(piece_id, hole_geom)
  -- ST_3DDifference(geom, hole_geom)
```

### Requêtes spatiales (conscience de l'agent)

```sql
-- "Est-ce que cette pièce touche quelque chose ?"
SELECT b.label FROM cad.piece a, cad.piece b
WHERE a.id = $1 AND a.id <> b.id AND ST_3DIntersects(a.geom, b.geom);

-- "Quelle est la distance entre ces deux pièces ?"
SELECT ST_3DDistance(a.geom, b.geom) FROM cad.piece a, cad.piece b
WHERE a.id = $1 AND b.id = $2;

-- "Volume total de bois ?"
SELECT sum(ST_3DVolume(geom)) / 1e9 AS volume_m3 FROM cad.piece WHERE drawing_id = $1;

-- "Bounding box du modèle ?"
SELECT ST_3DExtent(geom) FROM cad.piece WHERE drawing_id = $1;

-- "Toutes les pièces sont-elles connectées ?" (graphe connexe)
-- → recursive CTE sur cad.joint
```

### Rendu (scene_json pour le browser)

```sql
-- Exporter les triangles pour le viewer 3D
CREATE FUNCTION cad.scene_json(p_drawing_id int) RETURNS jsonb AS $$
  SELECT jsonb_agg(jsonb_build_object(
    'id', p.id,
    'label', p.label,
    'role', p.role,
    'wood_type', p.wood_type,
    'triangles', ST_AsGeoJSON(ST_Tesselate(p.geom))::jsonb
  ))
  FROM cad.piece p WHERE p.drawing_id = p_drawing_id;
$$ LANGUAGE sql;
```

### Plan de montage

```sql
-- Ordre d'assemblage (pièces les plus basses d'abord, puis connexions)
CREATE FUNCTION cad.assembly_order(p_drawing_id int) RETURNS TABLE(
  step int, piece_id int, label text, connects_to text[]
) AS $$
  -- 1. Trier par Z min (ce qui touche le sol en premier)
  -- 2. Puis par nombre de connexions (supports avant charges)
  -- 3. Retourner l'ordre avec les pièces auxquelles chaque pièce se connecte
$$ LANGUAGE plpgsql;

-- Vue éclatée pour une étape
CREATE FUNCTION cad.exploded_view(p_drawing_id int, p_step int) RETURNS jsonb AS $$
  -- Pièces posées (étapes <= p_step) : position normale
  -- Pièce en cours (étape = p_step) : surbrillance
  -- Pièces futures (étapes > p_step) : translatées vers le haut (éclatées)
$$ LANGUAGE sql;
```

## Viewer 3D (browser)

**Three.js** via CDN (pas JSCAD). Raison : les opérations CSG sont faites côté PostGIS/SFCGAL,
le browser ne fait que du rendu de triangles. Three.js `BufferGeometry` est conçu pour ça.

```
PostGIS                          Browser
───────                          ───────
ST_Tesselate(geom)          →    Three.js BufferGeometry
  → TIN (triangles)               + MeshPhongMaterial (bois)
  → ST_AsGeoJSON                   + OrbitControls (rotation/zoom)
  → JSON vertices/faces            + AmbientLight + DirectionalLight
```

CDN (zero build step) :
- `https://cdn.jsdelivr.net/npm/three@r183/build/three.module.min.js`
- `https://cdn.jsdelivr.net/npm/three@r183/examples/jsm/controls/OrbitControls.js`

Intégré dans pgView : PL/pgSQL génère le HTML avec un `<div id="cad-viewer">`
et un `<script type="module">` inline qui fetch `scene_json` + render.
Le shell pgView re-exécute les `<script>` tags injectés via innerHTML.

## Roadmap

### Phase 1 — Fondations (maintenant)
- [ ] PostGIS + SFCGAL dans l'image Docker
- [ ] DDL : `cad.piece` avec colonnes PostGIS
- [ ] `cad.add_piece()` : parse section → extrude → store
- [ ] `cad.scene_json()` : tesselate → JSON triangles
- [ ] Viewer 3D minimal dans pgView (un cube à l'écran)
- [ ] Requêtes spatiales de base (collisions, distances)

### Phase 2 — Modélisation
- [ ] `cad.move_piece()`, `cad.rotate_piece()`
- [ ] `cad.subtract_piece()` (CSG : tenon-mortaise)
- [ ] `cad.joint` view (détection automatique des connexions)
- [ ] Couleurs par essence/rôle dans le viewer
- [ ] Sélection de pièce au clic

### Phase 3 — Plans de montage
- [ ] `cad.assembly_order()` (graphe de dépendances)
- [ ] `cad.exploded_view()` (vue éclatée par étape)
- [ ] Rendu SVG des étapes (isométrique)
- [ ] Page pgView : plan de montage étape par étape

### Phase 4 — Export
- [ ] Liste de débit avec volumes exacts
- [ ] Export STL (impression 3D maquette)
- [ ] Export DXF (découpe CNC)
- [ ] PDF plan de montage
