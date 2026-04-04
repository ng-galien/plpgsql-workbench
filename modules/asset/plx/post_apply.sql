-- Add GENERATED columns and indexes that PLX entity-ddl does not support yet

-- Full-text search vector
ALTER TABLE asset.asset
  ADD COLUMN IF NOT EXISTS search_vec tsvector
  GENERATED ALWAYS AS (
    setweight(to_tsvector('simple', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(description, '')), 'B')
  ) STORED;

CREATE INDEX IF NOT EXISTS idx_asset_search ON asset.asset USING gin (search_vec);

-- Additional indexes
CREATE INDEX IF NOT EXISTS idx_asset_status ON asset.asset (tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_asset_tags ON asset.asset USING gin (tags);
