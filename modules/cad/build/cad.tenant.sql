-- CAD multi-tenant migration: add tenant_id + RLS to all tables
-- Also fix shape type CHECK to include 'group' + add parent_id for shape grouping

-- Fix shape type CHECK constraint
ALTER TABLE cad.shape DROP CONSTRAINT IF EXISTS shape_type_check;
ALTER TABLE cad.shape ADD CONSTRAINT shape_type_check
  CHECK (type IN ('line', 'rect', 'circle', 'arc', 'polyline', 'text', 'dimension', 'group'));

-- Add parent_id for shape grouping
ALTER TABLE cad.shape ADD COLUMN IF NOT EXISTS parent_id int REFERENCES cad.shape(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_shape_parent ON cad.shape(parent_id);

-- Add tenant_id columns (existing rows get 'dev')
ALTER TABLE cad.drawing ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'dev';
ALTER TABLE cad.layer ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'dev';
ALTER TABLE cad.shape ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'dev';
ALTER TABLE cad.piece ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'dev';
ALTER TABLE cad.piece_group ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'dev';

-- Switch defaults to session variable
ALTER TABLE cad.drawing ALTER COLUMN tenant_id SET DEFAULT COALESCE(current_setting('app.tenant_id', true), 'dev');
ALTER TABLE cad.layer ALTER COLUMN tenant_id SET DEFAULT COALESCE(current_setting('app.tenant_id', true), 'dev');
ALTER TABLE cad.shape ALTER COLUMN tenant_id SET DEFAULT COALESCE(current_setting('app.tenant_id', true), 'dev');
ALTER TABLE cad.piece ALTER COLUMN tenant_id SET DEFAULT COALESCE(current_setting('app.tenant_id', true), 'dev');
ALTER TABLE cad.piece_group ALTER COLUMN tenant_id SET DEFAULT COALESCE(current_setting('app.tenant_id', true), 'dev');

-- Indexes
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
