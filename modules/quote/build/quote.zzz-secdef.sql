-- RFC-001: SECURITY DEFINER on all write functions + revoke direct table writes

-- CRUD write functions
ALTER FUNCTION quote.devis_create(quote.devis) SECURITY DEFINER;
ALTER FUNCTION quote.devis_update(quote.devis) SECURITY DEFINER;
ALTER FUNCTION quote.devis_delete(text) SECURITY DEFINER;
ALTER FUNCTION quote.facture_create(quote.facture) SECURITY DEFINER;
ALTER FUNCTION quote.facture_update(quote.facture) SECURITY DEFINER;
ALTER FUNCTION quote.facture_delete(text) SECURITY DEFINER;

-- Legacy post_* write functions
ALTER FUNCTION quote.post_devis_save(jsonb) SECURITY DEFINER;
ALTER FUNCTION quote.post_devis_envoyer(jsonb) SECURITY DEFINER;
ALTER FUNCTION quote.post_devis_accepter(jsonb) SECURITY DEFINER;
ALTER FUNCTION quote.post_devis_refuser(jsonb) SECURITY DEFINER;
ALTER FUNCTION quote.post_devis_supprimer(jsonb) SECURITY DEFINER;
ALTER FUNCTION quote.post_devis_dupliquer(jsonb) SECURITY DEFINER;
ALTER FUNCTION quote.post_devis_facturer(jsonb) SECURITY DEFINER;
ALTER FUNCTION quote.post_facture_save(jsonb) SECURITY DEFINER;
ALTER FUNCTION quote.post_facture_envoyer(jsonb) SECURITY DEFINER;
ALTER FUNCTION quote.post_facture_payer(jsonb) SECURITY DEFINER;
ALTER FUNCTION quote.post_facture_supprimer(jsonb) SECURITY DEFINER;
ALTER FUNCTION quote.post_facture_relancer(jsonb) SECURITY DEFINER;
ALTER FUNCTION quote.post_ligne_ajouter(jsonb) SECURITY DEFINER;
ALTER FUNCTION quote.post_ligne_supprimer(jsonb) SECURITY DEFINER;

-- Revoke direct table writes from anon — all access through functions
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA quote FROM anon;
GRANT SELECT ON ALL TABLES IN SCHEMA quote TO anon;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA quote TO anon;
