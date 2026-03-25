-- purchase — English rename migration (Wave 2)

-- 1. Rename tables
ALTER TABLE IF EXISTS purchase.commande RENAME TO purchase_order;
ALTER TABLE IF EXISTS purchase.ligne RENAME TO order_line;
ALTER TABLE IF EXISTS purchase.reception RENAME TO receipt;
ALTER TABLE IF EXISTS purchase.reception_ligne RENAME TO receipt_line;
ALTER TABLE IF EXISTS purchase.facture_fournisseur RENAME TO supplier_invoice;

-- 2. Rename columns: purchase_order
ALTER TABLE purchase.purchase_order RENAME COLUMN numero TO number;
ALTER TABLE purchase.purchase_order RENAME COLUMN fournisseur_id TO supplier_id;
ALTER TABLE purchase.purchase_order RENAME COLUMN objet TO subject;
ALTER TABLE purchase.purchase_order RENAME COLUMN statut TO status;
ALTER TABLE purchase.purchase_order RENAME COLUMN date_livraison TO delivery_date;
ALTER TABLE purchase.purchase_order RENAME COLUMN conditions_paiement TO payment_terms;

-- 3. Rename columns: order_line
ALTER TABLE purchase.order_line RENAME COLUMN commande_id TO order_id;
ALTER TABLE purchase.order_line RENAME COLUMN quantite TO quantity;
ALTER TABLE purchase.order_line RENAME COLUMN unite TO unit;
ALTER TABLE purchase.order_line RENAME COLUMN prix_unitaire TO unit_price;

-- 4. Rename columns: receipt
ALTER TABLE purchase.receipt RENAME COLUMN commande_id TO order_id;
ALTER TABLE purchase.receipt RENAME COLUMN numero TO number;

-- 5. Rename columns: receipt_line
ALTER TABLE purchase.receipt_line RENAME COLUMN ligne_id TO line_id;
ALTER TABLE purchase.receipt_line RENAME COLUMN quantite_recue TO quantity_received;

-- 6. Rename columns: supplier_invoice
ALTER TABLE purchase.supplier_invoice RENAME COLUMN commande_id TO order_id;
ALTER TABLE purchase.supplier_invoice RENAME COLUMN numero_fournisseur TO supplier_ref;
ALTER TABLE purchase.supplier_invoice RENAME COLUMN montant_ht TO amount_excl_tax;
ALTER TABLE purchase.supplier_invoice RENAME COLUMN montant_ttc TO amount_incl_tax;
ALTER TABLE purchase.supplier_invoice RENAME COLUMN date_facture TO invoice_date;
ALTER TABLE purchase.supplier_invoice RENAME COLUMN date_echeance TO due_date;
ALTER TABLE purchase.supplier_invoice RENAME COLUMN statut TO status;
ALTER TABLE purchase.supplier_invoice RENAME COLUMN comptabilisee TO posted;

-- 7. Drop old CHECK constraints BEFORE updating values
ALTER TABLE purchase.purchase_order DROP CONSTRAINT IF EXISTS commande_statut_check;
ALTER TABLE purchase.supplier_invoice DROP CONSTRAINT IF EXISTS facture_fournisseur_statut_check;

-- 8. Update status values: purchase_order
UPDATE purchase.purchase_order SET status = CASE status
  WHEN 'brouillon' THEN 'draft'
  WHEN 'envoyee' THEN 'sent'
  WHEN 'partiellement_recue' THEN 'partially_received'
  WHEN 'recue' THEN 'received'
  WHEN 'annulee' THEN 'cancelled'
  ELSE status
END;

-- 9. Update status values: supplier_invoice
UPDATE purchase.supplier_invoice SET status = CASE status
  WHEN 'recue' THEN 'received'
  WHEN 'validee' THEN 'validated'
  WHEN 'payee' THEN 'paid'
  ELSE status
END;

-- 10. Add new CHECK constraints
ALTER TABLE purchase.purchase_order ADD CONSTRAINT purchase_order_status_check
  CHECK (status IN ('draft', 'sent', 'partially_received', 'received', 'cancelled'));

ALTER TABLE purchase.supplier_invoice ADD CONSTRAINT supplier_invoice_status_check
  CHECK (status IN ('received', 'validated', 'paid'));

-- 10. Update default values
ALTER TABLE purchase.purchase_order ALTER COLUMN status SET DEFAULT 'draft';
ALTER TABLE purchase.supplier_invoice ALTER COLUMN status SET DEFAULT 'received';

-- 11. RLS policies (re-create with new table names)
DROP POLICY IF EXISTS tenant_isolation ON purchase.purchase_order;
CREATE POLICY tenant_isolation ON purchase.purchase_order
  USING (tenant_id = current_setting('app.tenant_id', true));

DROP POLICY IF EXISTS tenant_isolation ON purchase.order_line;
CREATE POLICY tenant_isolation ON purchase.order_line
  USING (tenant_id = current_setting('app.tenant_id', true));

DROP POLICY IF EXISTS tenant_isolation ON purchase.receipt;
CREATE POLICY tenant_isolation ON purchase.receipt
  USING (tenant_id = current_setting('app.tenant_id', true));

DROP POLICY IF EXISTS tenant_isolation ON purchase.receipt_line;
CREATE POLICY tenant_isolation ON purchase.receipt_line
  USING (tenant_id = current_setting('app.tenant_id', true));

DROP POLICY IF EXISTS tenant_isolation ON purchase.supplier_invoice;
CREATE POLICY tenant_isolation ON purchase.supplier_invoice
  USING (tenant_id = current_setting('app.tenant_id', true));

-- 12. Table security
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA purchase FROM anon;
GRANT SELECT ON ALL TABLES IN SCHEMA purchase TO anon;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA purchase TO anon;
