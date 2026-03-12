CREATE OR REPLACE FUNCTION purchase_qa.clean()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);
  DELETE FROM purchase.reception_ligne;
  DELETE FROM purchase.reception;
  DELETE FROM purchase.facture_fournisseur;
  DELETE FROM purchase.ligne;
  DELETE FROM purchase.commande;
  DELETE FROM crm.client WHERE tags @> ARRAY['fournisseur'];
  RETURN 'purchase_qa.clean() OK';
END;
$function$;
