-- Quote — Seed data (reference data, tenant_id = '_ref')
-- Legal notices for artisans

SELECT set_config('app.tenant_id', '_ref', false);

INSERT INTO quote.legal_notice (label, body) VALUES
  ('Délai de paiement', 'Paiement à 30 jours à compter de la date de facturation.'),
  ('Pénalités de retard', 'En cas de retard de paiement, des pénalités de retard seront appliquées au taux annuel de 10%, conformément à l''article L441-10 du Code de commerce.'),
  ('Indemnité forfaitaire', 'Une indemnité forfaitaire de 40 EUR pour frais de recouvrement sera due en cas de retard de paiement (art. D441-5 du Code de commerce).'),
  ('Validité du devis', 'Ce devis est valable pour la durée indiquée à compter de sa date d''émission.'),
  ('Garantie', 'Garantie décennale et responsabilité civile professionnelle.')
ON CONFLICT DO NOTHING;
