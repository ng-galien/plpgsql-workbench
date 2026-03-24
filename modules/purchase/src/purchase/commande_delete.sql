CREATE OR REPLACE FUNCTION purchase.commande_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_row purchase.commande;
BEGIN
  DELETE FROM purchase.commande
  WHERE id = p_id::int
    AND tenant_id = current_setting('app.tenant_id', true)
    AND statut = 'brouillon'
  RETURNING * INTO v_row;
  RETURN to_jsonb(v_row);
END;
$function$;
