-- asset — DDL (v5: add thumb_path migration)

CREATE SCHEMA IF NOT EXISTS asset;
CREATE SCHEMA IF NOT EXISTS asset_ut;
CREATE SCHEMA IF NOT EXISTS asset_qa;

CREATE TABLE IF NOT EXISTS asset.asset (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     TEXT NOT NULL DEFAULT current_setting('app.tenant_id', true),
  path          TEXT NOT NULL,
  filename      TEXT NOT NULL,
  mime_type     TEXT NOT NULL DEFAULT 'image/jpeg',
  status        TEXT NOT NULL DEFAULT 'to_classify'
                CHECK (status IN ('to_classify', 'classified', 'archived')),
  -- Dimensions
  width         INTEGER,
  height        INTEGER,
  orientation   TEXT,
  -- Métadonnées (remplies par Claude via classify)
  title         TEXT,
  description   TEXT,
  tags          TEXT[] DEFAULT '{}',
  credit        TEXT,
  saison        TEXT,
  usage_hint    TEXT,
  colors        TEXT[] DEFAULT '{}',
  -- Thumbnail
  thumb_path    TEXT,
  -- Timestamps
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  classified_at TIMESTAMPTZ,
  -- FTS (title + description, tags indexed separately via GIN)
  search_vec    tsvector GENERATED ALWAYS AS (
    setweight(to_tsvector('pgv_search', coalesce(title,'')), 'A') ||
    setweight(to_tsvector('pgv_search', coalesce(description,'')), 'B')
  ) STORED
);

-- Migration: add thumb_path if missing (CREATE TABLE IF NOT EXISTS doesn't alter)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'asset' AND table_name = 'asset' AND column_name = 'thumb_path') THEN
    ALTER TABLE asset.asset ADD COLUMN thumb_path TEXT;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_asset_search ON asset.asset USING GIN(search_vec);
CREATE INDEX IF NOT EXISTS idx_asset_tenant ON asset.asset(tenant_id);
CREATE INDEX IF NOT EXISTS idx_asset_status ON asset.asset(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_asset_tags   ON asset.asset USING GIN(tags);

-- Grants
GRANT USAGE ON SCHEMA asset TO anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA asset TO anon;
GRANT SELECT ON ALL TABLES IN SCHEMA asset TO anon;

GRANT USAGE ON SCHEMA asset_ut TO anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA asset_ut TO anon;

GRANT USAGE ON SCHEMA asset_qa TO anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA asset_qa TO anon;
