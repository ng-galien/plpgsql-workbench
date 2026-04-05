-- Soft delete overrides: PLX generates hard DELETE but stock preserves movement history
CREATE OR REPLACE FUNCTION stock.article_delete(p_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = stock, pg_catalog, pg_temp AS $$
BEGIN
  UPDATE stock.article SET active = false
  WHERE id = p_id::int
    AND tenant_id = current_setting('app.tenant_id', true);
  RETURN (SELECT to_jsonb(a) FROM stock.article a WHERE id = p_id::int);
END; $$;

CREATE OR REPLACE FUNCTION stock.warehouse_delete(p_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = stock, pg_catalog, pg_temp AS $$
BEGIN
  UPDATE stock.warehouse SET active = false
  WHERE id = p_id::int
    AND tenant_id = current_setting('app.tenant_id', true);
  RETURN (SELECT to_jsonb(w) FROM stock.warehouse w WHERE id = p_id::int);
END; $$;

-- Nullify orphaned supplier references before adding FK
UPDATE stock.article
SET supplier_id = NULL
WHERE supplier_id IS NOT NULL
  AND supplier_id NOT IN (SELECT id FROM crm.client);

-- FK article -> crm.client (supplier)
ALTER TABLE stock.article DROP CONSTRAINT IF EXISTS article_supplier_id_fkey;
ALTER TABLE stock.article ADD CONSTRAINT article_supplier_id_fkey
  FOREIGN KEY (supplier_id) REFERENCES crm.client(id);

-- Transfer constraint: destination_warehouse_id required for transfer type
ALTER TABLE stock.movement DROP CONSTRAINT IF EXISTS chk_transfer_destination;
ALTER TABLE stock.movement ADD CONSTRAINT chk_transfer_destination
  CHECK (
    (type = 'transfer' AND destination_warehouse_id IS NOT NULL)
    OR (type <> 'transfer' AND destination_warehouse_id IS NULL)
  );

-- Unique article reference per tenant (scoped, not global)
DROP INDEX IF EXISTS idx_article_tenant_ref;
CREATE UNIQUE INDEX IF NOT EXISTS idx_article_tenant_ref
  ON stock.article(tenant_id, reference);
