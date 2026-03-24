CREATE OR REPLACE FUNCTION purchase.facture_fournisseur_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_row purchase.facture_fournisseur;
BEGIN
  DELETE FROM purchase.facture_fournisseur
  WHERE id = p_id::int
    AND tenant_id = current_setting('app.tenant_id', true)
    AND statut = 'recue'
  RETURNING * INTO v_row;
  RETURN to_jsonb(v_row);
END;
$function$;
