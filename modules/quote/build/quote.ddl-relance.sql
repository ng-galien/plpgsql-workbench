-- Add 'relance' status to facture
ALTER TABLE quote.facture DROP CONSTRAINT IF EXISTS facture_statut_check;
ALTER TABLE quote.facture ADD CONSTRAINT facture_statut_check
  CHECK (statut IN ('brouillon', 'envoyee', 'payee', 'relance'));
