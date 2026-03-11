-- Fix FK CASCADE on client_id (crm_qa.seed needs to DELETE FROM crm.client)
ALTER TABLE quote.devis DROP CONSTRAINT devis_client_id_fkey;
ALTER TABLE quote.devis ADD CONSTRAINT devis_client_id_fkey FOREIGN KEY (client_id) REFERENCES crm.client(id) ON DELETE CASCADE;

ALTER TABLE quote.facture DROP CONSTRAINT facture_client_id_fkey;
ALTER TABLE quote.facture ADD CONSTRAINT facture_client_id_fkey FOREIGN KEY (client_id) REFERENCES crm.client(id) ON DELETE CASCADE;
