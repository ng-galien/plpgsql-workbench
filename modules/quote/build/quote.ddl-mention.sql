-- Mentions légales (conditions, pénalités retard, etc.)
CREATE TABLE IF NOT EXISTS quote.mention (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  label text NOT NULL,
  texte text NOT NULL,
  active boolean NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_mention_tenant ON quote.mention(tenant_id);

ALTER TABLE quote.mention ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY tenant_isolation ON quote.mention
    USING (tenant_id = current_setting('app.tenant_id', true));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON quote.mention TO anon;
GRANT USAGE ON SEQUENCE quote.mention_id_seq TO anon;

-- Mentions obligatoires artisan (pré-remplissage)
INSERT INTO quote.mention (label, texte)
SELECT label, texte FROM (VALUES
  ('Délai de paiement', 'Paiement à 30 jours à compter de la date de facturation.'),
  ('Pénalités de retard', 'En cas de retard de paiement, des pénalités de retard seront appliquées au taux annuel de 10%, conformément à l''article L441-10 du Code de commerce.'),
  ('Indemnité forfaitaire', 'Une indemnité forfaitaire de 40 EUR pour frais de recouvrement sera due en cas de retard de paiement (art. D441-5 du Code de commerce).'),
  ('Validité du devis', 'Ce devis est valable pour la durée indiquée à compter de sa date d''émission.'),
  ('Garantie', 'Garantie décennale et responsabilité civile professionnelle.')
) AS m(label, texte)
WHERE NOT EXISTS (SELECT 1 FROM quote.mention LIMIT 1);
