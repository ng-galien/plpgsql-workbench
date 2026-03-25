-- Drop remaining old French-named functions with renamed composite types
DROP FUNCTION IF EXISTS quote.devis_create(quote.estimate);
DROP FUNCTION IF EXISTS quote.devis_update(quote.estimate);
DROP FUNCTION IF EXISTS quote.facture_create(quote.invoice);
DROP FUNCTION IF EXISTS quote.facture_update(quote.invoice);
