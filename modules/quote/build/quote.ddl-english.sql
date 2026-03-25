-- RFC-001: Language rename — French to English for all quote tables, columns, status values

-- Phase 1: Rename tables
ALTER TABLE quote.devis RENAME TO estimate;
ALTER TABLE quote.facture RENAME TO invoice;
ALTER TABLE quote.ligne RENAME TO line_item;
ALTER TABLE quote.mention RENAME TO legal_notice;

-- Phase 2: Rename columns — estimate (was devis)
ALTER TABLE quote.estimate RENAME COLUMN numero TO number;
ALTER TABLE quote.estimate RENAME COLUMN objet TO subject;
ALTER TABLE quote.estimate RENAME COLUMN statut TO status;
ALTER TABLE quote.estimate RENAME COLUMN validite_jours TO validity_days;

-- Phase 2: Rename columns — invoice (was facture)
ALTER TABLE quote.invoice RENAME COLUMN numero TO number;
ALTER TABLE quote.invoice RENAME COLUMN objet TO subject;
ALTER TABLE quote.invoice RENAME COLUMN statut TO status;
ALTER TABLE quote.invoice RENAME COLUMN devis_id TO estimate_id;

-- Phase 2: Rename columns — line_item (was ligne)
ALTER TABLE quote.line_item RENAME COLUMN devis_id TO estimate_id;
ALTER TABLE quote.line_item RENAME COLUMN facture_id TO invoice_id;
ALTER TABLE quote.line_item RENAME COLUMN quantite TO quantity;
ALTER TABLE quote.line_item RENAME COLUMN unite TO unit;
ALTER TABLE quote.line_item RENAME COLUMN prix_unitaire TO unit_price;

-- Phase 2: Rename columns — legal_notice (was mention)
ALTER TABLE quote.legal_notice RENAME COLUMN texte TO body;

-- Phase 3: Drop old CHECK constraints first, then update values, then add new constraints
ALTER TABLE quote.estimate DROP CONSTRAINT IF EXISTS devis_statut_check;
ALTER TABLE quote.invoice DROP CONSTRAINT IF EXISTS facture_statut_check;

UPDATE quote.estimate SET status = 'draft' WHERE status = 'brouillon';
UPDATE quote.estimate SET status = 'sent' WHERE status = 'envoye';
UPDATE quote.estimate SET status = 'accepted' WHERE status = 'accepte';
UPDATE quote.estimate SET status = 'declined' WHERE status = 'refuse';

ALTER TABLE quote.estimate ADD CONSTRAINT estimate_status_check
  CHECK (status IN ('draft', 'sent', 'accepted', 'declined'));

UPDATE quote.invoice SET status = 'draft' WHERE status = 'brouillon';
UPDATE quote.invoice SET status = 'sent' WHERE status = 'envoyee';
UPDATE quote.invoice SET status = 'paid' WHERE status = 'payee';
UPDATE quote.invoice SET status = 'overdue' WHERE status = 'relance';

ALTER TABLE quote.invoice ADD CONSTRAINT invoice_status_check
  CHECK (status IN ('draft', 'sent', 'paid', 'overdue'));

-- Phase 4: Rename XOR constraint
ALTER TABLE quote.line_item DROP CONSTRAINT IF EXISTS ligne_parent_xor;
ALTER TABLE quote.line_item ADD CONSTRAINT line_item_parent_xor
  CHECK ((estimate_id IS NOT NULL AND invoice_id IS NULL)
      OR (estimate_id IS NULL AND invoice_id IS NOT NULL));

-- Phase 5: Rename indexes
ALTER INDEX IF EXISTS quote.idx_devis_client RENAME TO idx_estimate_client;
ALTER INDEX IF EXISTS quote.idx_devis_statut RENAME TO idx_estimate_status;
ALTER INDEX IF EXISTS quote.idx_devis_tenant RENAME TO idx_estimate_tenant;
ALTER INDEX IF EXISTS quote.idx_facture_client RENAME TO idx_invoice_client;
ALTER INDEX IF EXISTS quote.idx_facture_devis RENAME TO idx_invoice_estimate;
ALTER INDEX IF EXISTS quote.idx_facture_statut RENAME TO idx_invoice_status;
ALTER INDEX IF EXISTS quote.idx_facture_tenant RENAME TO idx_invoice_tenant;
ALTER INDEX IF EXISTS quote.idx_ligne_devis RENAME TO idx_line_item_estimate;
ALTER INDEX IF EXISTS quote.idx_ligne_facture RENAME TO idx_line_item_invoice;
ALTER INDEX IF EXISTS quote.idx_ligne_tenant RENAME TO idx_line_item_tenant;
ALTER INDEX IF EXISTS quote.idx_mention_tenant RENAME TO idx_legal_notice_tenant;

-- Phase 6: Rename RLS policies
DROP POLICY IF EXISTS tenant_isolation ON quote.estimate;
CREATE POLICY tenant_isolation ON quote.estimate
  USING (tenant_id = current_setting('app.tenant_id', true));

DROP POLICY IF EXISTS tenant_isolation ON quote.invoice;
CREATE POLICY tenant_isolation ON quote.invoice
  USING (tenant_id = current_setting('app.tenant_id', true));

DROP POLICY IF EXISTS tenant_isolation ON quote.line_item;
CREATE POLICY tenant_isolation ON quote.line_item
  USING (tenant_id = current_setting('app.tenant_id', true));

DROP POLICY IF EXISTS tenant_isolation ON quote.legal_notice;
CREATE POLICY tenant_isolation ON quote.legal_notice
  USING (tenant_id = current_setting('app.tenant_id', true));

-- Phase 7: Security — reapply after rename
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA quote FROM anon;
GRANT SELECT ON ALL TABLES IN SCHEMA quote TO anon;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA quote TO anon;
