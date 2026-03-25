CREATE OR REPLACE FUNCTION quote.facture_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_row quote.facture;
BEGIN
  SELECT * INTO v_row FROM quote.facture WHERE id = p_id::int AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN RAISE EXCEPTION '%', pgv.t('quote.err_not_found_facture'); END IF;
  IF v_row.statut <> 'brouillon' THEN RAISE EXCEPTION '%', pgv.t('quote.err_draft_delete_only'); END IF;

  DELETE FROM quote.facture WHERE id = p_id::int AND tenant_id = current_setting('app.tenant_id', true);
  RETURN to_jsonb(v_row);
END;
$function$;
