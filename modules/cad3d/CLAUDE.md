# cad3d — CAD 3D Wood Structures

3D CAD engine for small wood structures (sheds, workshops, shelters). PostGIS/SFCGAL geometry, Three.js viewer, SVG wireframe, bill of materials.

**Requires:** `postgis` + `postgis_sfcgal` extensions, `pgv` module.

## Schemas

| Schema | Role | Functions |
|--------|------|-----------|
| `cad` | Core CAD + pages | 50 |
| `cad_ut` | pgTAP tests | 5 |

## Layout

```
build/cad.ddl.sql        # Schema + 4 tables + grants (88 lines)
build/cad.func.sql       # pg_pack output (cad + cad_ut + cad_qa, dependency-sorted)
src/cad/*.sql            # Function sources (pg_func_save)
src/cad_ut/test_*.sql    # Test sources (pg_func_save)
qa/cad_qa/*.sql          # QA/demo sources (pg_func_save — _qa suffix → qa/)
frontend/cad3d.js        # Alpine.js: cadViewer (Three.js) + cadTree (shape explorer)
frontend/cad3d.css       # Viewer + toolbar + info panel styles
```

## Data Model

| Table | Purpose | Key columns |
|-------|---------|-------------|
| `cad.drawing` | Project container | name, scale, unit (mm/cm/m), width, height |
| `cad.layer` | 2D drawing layers | color, stroke_width, visible, locked, sort_order |
| `cad.shape` | 2D primitives | type, geometry (jsonb), props (jsonb), label |
| `cad.piece` | 3D wood beams | profile (POLYGONZ), geom (POLYHEDRALSURFACEZ), section, role, wood_type, length_mm |

Shape types: line, rect, circle, arc, polyline, text, dimension, group.

## Functions by Category

**3D Geometry (core)**
- `add_piece(drawing_id, section, length_mm, position[], rotation[], ...)` — Create beam: parse section -> profile -> extrude -> rotate -> translate
- `move_piece`, `resize_piece`, `duplicate_piece`, `remove_piece`, `snap_piece`
- `faces(piece_id)`, `cross_section(piece_id)`, `neighbors(piece_id)`
- `assembly_order(drawing_id)` — Topological sort by connectivity
- `measure(drawing_id)`, `list_pieces(drawing_id)`

**2D Shapes**
- `add_shape`, `delete_shape`, `move_shape`, `move_group`
- `group_shapes(drawing_id, shape_ids[], label)`, `ungroup(group_id)`

**Rendering**
- `render_svg(drawing_id)` — 2D orthographic (layers as `<g>`, recursive groups)
- `render_wireframe(drawing_id, axis, w, h)` — 3D orthographic projection with grid, labels, legend
- `scene_json(drawing_id)` — GeoJSON PolyhedralSurfaces for Three.js
- `render_dimension`, `render_arc`, `render_perspective`

**Pages (pgView)**
- `page(path, body)` — Master dispatcher (custom routing for /drawing/:id paths)
- `page_index()` — Drawing list + new form
- `page_drawing(id)` — 2D editor (tree + SVG canvas + shape form)
- `page_drawing_3d(id)` — Three.js 3D viewer + wireframe + stats
- `page_drawing_bom(id)` — Bill of materials
- `page_drawing_add`, `page_drawing_add_shape`, `page_drawing_delete_shape` — POST actions

**Inspection**
- `bill_of_materials(drawing_id)` — Text BOM (qty x section wood_type [role])
- `check(drawing_id)` — Collision detection, orphans, underground/floating pieces
- `inspect(drawing_id)` — Full model summary
- `help(filter)` — Function listing via pg_proc

## PostGIS/SFCGAL Patterns

```sql
-- Section "60x90" -> rectangular profile in Z=0 plane
v_profile := ST_MakePolygon(ST_MakeLine(ARRAY[
  ST_MakePoint(0,0,0), ST_MakePoint(w,0,0),
  ST_MakePoint(w,h,0), ST_MakePoint(0,h,0), ST_MakePoint(0,0,0)
]));

-- Extrude along Z
v_solid := ST_Extrude(v_profile, 0, 0, p_length_mm);

-- Rotate (degrees -> radians, order: RZ, RY, RX)
v_solid := ST_RotateX(v_solid, radians(p_rotation[3]));
v_solid := ST_RotateY(v_solid, radians(p_rotation[2]));
v_solid := ST_RotateZ(v_solid, radians(p_rotation[1]));

-- Translate to position
v_solid := ST_Translate(v_solid, p_position[1], p_position[2], p_position[3]);

-- Collision: volume > 100mm³ = overlap (not just contact)
ST_Volume(ST_3DIntersection(a.geom, b.geom))

-- Tesselation for Three.js mesh export
ST_Tesselate(face.geom) -> triangles for GeoJSON
```

## Conventions

- **UI language:** French (Dessins, Calques, Echelle, Montant, Traverse, Chevron, Lisse, Poteau)
- **Section format:** `"WxH"` string (e.g. "60x90"), parsed via `string_to_array(section, 'x')`
- **Units:** mm (storage), m³ (volume display = mm³ / 1e9)
- **Coordinate system:** Z=0 = ground, Z > 0 = up
- **Rotation order:** RZ first, then RY, then RX (angles in degrees)
- **Wood type:** default `'pin'` (pine)
- **Roles:** montant, traverse, chevron, lisse, poteau — color-coded in wireframe + Three.js
- **Custom routing:** `cad.page(path, body)` handles dynamic routes (`/drawing/:id`) then delegates static routes to `pgv.route()`

## Three.js Integration

- `cad3d.js`: Alpine `cadViewer` component, lazy-loads Three.js r183 from CDN (`threejs-with-controls` UMD bundle — single script, includes OrbitControls)
- `scene_json()` returns GeoJSON PolyhedralSurfaces (tesselated triangles)
- Piece colors by role (hardcoded in JS, must match SVG wireframe legend)
- Raycaster click selection (Shift = multi-select), OrbitControls with damping

## File Export Convention

`pg_func_save` auto-resolves output directories via module registry:
- `cad`, `cad_ut` schemas → **`src/`** (`src/cad/*.sql`, `src/cad_ut/*.sql`)
- `cad_qa` schema → **`qa/`** (`qa/cad_qa/*.sql`)

NEVER move QA files from `qa/` to `src/`. The registry decides based on schema suffix `_qa`.

## Testing

```
pg_test target: "plpgsql://cad_ut"    # Run 5 tests
```

Tests: add_shape, delete_shape, group_shapes, move_shape, render_svg. Cleanup via CASCADE on drawing FK.

## Gotchas

- **PostgREST Content-Profile:** Any direct `fetch('/rpc/...')` from JS must include `Content-Profile: cad` header, otherwise PostgREST looks in the default schema (pgv)
- **Docker image:** Needs `postgis/postgis:17-3.5` (NOT Supabase image) for SFCGAL
- **ST_Volume() returns mm³** — Divide by 1e9 for m³
- **Overlap threshold:** < 100mm³ = contact (ok), > 100mm³ = collision (error in `check()`)
- **`_abbrev()` is hardcoded** — French naming patterns (Poteau, Chevron AV-%, etc.), fallback = `left(label, 3)`
- **Piece colors in JS must match SVG** — Hardcoded in both `cad3d.js` and `render_wireframe()`
- **pgv_qa-style pages:** `page()` does its own path parsing for `/drawing/:id` routes, static routes delegate to `pgv.route()`
