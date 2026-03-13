-- CAD 2D/3D — DDL

CREATE SCHEMA IF NOT EXISTS cad;
CREATE SCHEMA IF NOT EXISTS cad_ut;
CREATE SCHEMA IF NOT EXISTS cad_qa;
GRANT USAGE ON SCHEMA cad TO web_anon;

-- Dessins
CREATE TABLE IF NOT EXISTS cad.drawing (
  id serial PRIMARY KEY,
  name text NOT NULL,
  scale real NOT NULL DEFAULT 1.0,
  unit text NOT NULL DEFAULT 'mm' CHECK (unit IN ('mm', 'cm', 'm')),
  width real NOT NULL DEFAULT 2000,
  height real NOT NULL DEFAULT 1500,
  tenant_id text NOT NULL DEFAULT COALESCE(current_setting('app.tenant_id', true), 'dev'),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Calques
CREATE TABLE IF NOT EXISTS cad.layer (
  id serial PRIMARY KEY,
  drawing_id int NOT NULL REFERENCES cad.drawing(id) ON DELETE CASCADE,
  name text NOT NULL,
  color text NOT NULL DEFAULT '#000000',
  stroke_width real NOT NULL DEFAULT 1.0,
  visible boolean NOT NULL DEFAULT true,
  locked boolean NOT NULL DEFAULT false,
  sort_order int NOT NULL DEFAULT 0,
  tenant_id text NOT NULL DEFAULT COALESCE(current_setting('app.tenant_id', true), 'dev'),
  UNIQUE (drawing_id, name)
);

CREATE INDEX IF NOT EXISTS idx_layer_drawing ON cad.layer(drawing_id);

-- Shapes (primitives 2D)
CREATE TABLE IF NOT EXISTS cad.shape (
  id serial PRIMARY KEY,
  drawing_id int NOT NULL REFERENCES cad.drawing(id) ON DELETE CASCADE,
  layer_id int NOT NULL REFERENCES cad.layer(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('line', 'rect', 'circle', 'arc', 'polyline', 'text', 'dimension', 'group')),
  parent_id int REFERENCES cad.shape(id) ON DELETE CASCADE,
  geometry jsonb NOT NULL DEFAULT '{}',
  props jsonb NOT NULL DEFAULT '{}',
  label text,
  tenant_id text NOT NULL DEFAULT COALESCE(current_setting('app.tenant_id', true), 'dev'),
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_shape_drawing ON cad.shape(drawing_id);
CREATE INDEX IF NOT EXISTS idx_shape_layer ON cad.shape(layer_id);
CREATE INDEX IF NOT EXISTS idx_shape_type ON cad.shape(type);

-- Pièces 3D (PostGIS + SFCGAL)
CREATE TABLE IF NOT EXISTS cad.piece (
  id serial PRIMARY KEY,
  drawing_id int NOT NULL REFERENCES cad.drawing(id) ON DELETE CASCADE,
  label text,
  role text,                           -- montant, traverse, chevron, lisse, poteau
  wood_type text NOT NULL DEFAULT 'pin',
  section text NOT NULL,               -- "60x60", "45x90", "60x120"
  length_mm real NOT NULL,

  -- Géométrie PostGIS
  profile geometry(POLYGONZ, 0),       -- section 2D positionnée en Z=0
  geom geometry(POLYHEDRALSURFACEZ, 0),-- solide 3D extrudé

  tenant_id text NOT NULL DEFAULT COALESCE(current_setting('app.tenant_id', true), 'dev'),
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_piece_drawing ON cad.piece(drawing_id);
CREATE INDEX IF NOT EXISTS idx_piece_geom ON cad.piece USING gist(geom);

-- Groupes de pièces (sous-assemblages)
CREATE TABLE IF NOT EXISTS cad.piece_group (
  id serial PRIMARY KEY,
  drawing_id int NOT NULL REFERENCES cad.drawing(id) ON DELETE CASCADE,
  parent_id int REFERENCES cad.piece_group(id) ON DELETE CASCADE,
  label text NOT NULL,
  tenant_id text NOT NULL DEFAULT COALESCE(current_setting('app.tenant_id', true), 'dev'),
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_piece_group_drawing ON cad.piece_group(drawing_id);
CREATE INDEX IF NOT EXISTS idx_piece_group_parent ON cad.piece_group(parent_id);

ALTER TABLE cad.piece ADD COLUMN IF NOT EXISTS group_id int
  REFERENCES cad.piece_group(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_piece_group ON cad.piece(group_id);

-- Permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON cad.piece_group TO web_anon;
GRANT USAGE ON SEQUENCE cad.piece_group_id_seq TO web_anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON cad.piece TO web_anon;
GRANT USAGE ON SEQUENCE cad.piece_id_seq TO web_anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON cad.drawing TO web_anon;
GRANT USAGE ON SEQUENCE cad.drawing_id_seq TO web_anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON cad.layer TO web_anon;
GRANT USAGE ON SEQUENCE cad.layer_id_seq TO web_anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON cad.shape TO web_anon;
GRANT USAGE ON SEQUENCE cad.shape_id_seq TO web_anon;

GRANT USAGE ON SCHEMA cad_ut TO web_anon;
GRANT USAGE ON SCHEMA cad_qa TO web_anon;

-- Default privileges pour les fonctions créées après le DDL
ALTER DEFAULT PRIVILEGES IN SCHEMA cad GRANT EXECUTE ON FUNCTIONS TO web_anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA cad_ut GRANT EXECUTE ON FUNCTIONS TO web_anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA cad_qa GRANT EXECUTE ON FUNCTIONS TO web_anon;

-- Dimension (2D/3D)
ALTER TABLE cad.drawing ADD COLUMN IF NOT EXISTS dimension text
  NOT NULL DEFAULT '2d' CHECK (dimension IN ('2d', '3d'));

-- Tenant indexes
CREATE INDEX IF NOT EXISTS idx_drawing_tenant ON cad.drawing(tenant_id);
CREATE INDEX IF NOT EXISTS idx_layer_tenant ON cad.layer(tenant_id);
CREATE INDEX IF NOT EXISTS idx_shape_tenant ON cad.shape(tenant_id);
CREATE INDEX IF NOT EXISTS idx_piece_tenant ON cad.piece(tenant_id);
CREATE INDEX IF NOT EXISTS idx_piece_group_tenant ON cad.piece_group(tenant_id);

-- RLS
ALTER TABLE cad.drawing ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON cad.drawing;
CREATE POLICY tenant_isolation ON cad.drawing
  USING (tenant_id = COALESCE(current_setting('app.tenant_id', true), 'dev'));

ALTER TABLE cad.layer ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON cad.layer;
CREATE POLICY tenant_isolation ON cad.layer
  USING (tenant_id = COALESCE(current_setting('app.tenant_id', true), 'dev'));

ALTER TABLE cad.shape ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON cad.shape;
CREATE POLICY tenant_isolation ON cad.shape
  USING (tenant_id = COALESCE(current_setting('app.tenant_id', true), 'dev'));

ALTER TABLE cad.piece ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON cad.piece;
CREATE POLICY tenant_isolation ON cad.piece
  USING (tenant_id = COALESCE(current_setting('app.tenant_id', true), 'dev'));

ALTER TABLE cad.piece_group ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON cad.piece_group;
CREATE POLICY tenant_isolation ON cad.piece_group
  USING (tenant_id = COALESCE(current_setting('app.tenant_id', true), 'dev'));
