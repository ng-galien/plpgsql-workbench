-- FTS index on article name (French)
CREATE INDEX IF NOT EXISTS idx_article_name_fts ON catalog.article USING gin (to_tsvector('french', coalesce(name, '')));

-- Additional indexes
CREATE INDEX IF NOT EXISTS idx_article_barcode ON catalog.article (barcode) WHERE barcode IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_supplier_article ON catalog.supplier_article (article_id);
CREATE INDEX IF NOT EXISTS idx_pricing_tier_article ON catalog.pricing_tier (article_id, min_qty);
