-- CAD 2D — Groups support (parent_id on shape)

ALTER TABLE cad.shape ADD COLUMN IF NOT EXISTS parent_id int REFERENCES cad.shape(id) ON DELETE CASCADE;

ALTER TABLE cad.shape DROP CONSTRAINT IF EXISTS shape_type_check;
ALTER TABLE cad.shape ADD CONSTRAINT shape_type_check
  CHECK (type IN ('line','rect','circle','arc','polyline','text','dimension','group'));

CREATE INDEX IF NOT EXISTS idx_shape_parent ON cad.shape(parent_id);
