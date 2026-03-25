CREATE OR REPLACE FUNCTION quote.estimate_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_row quote.estimate;
BEGIN
  SELECT * INTO v_row FROM quote.estimate WHERE id = p_id::int AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN RAISE EXCEPTION '%', pgv.t('quote.err_not_found_estimate'); END IF;
  IF v_row.status <> 'draft' THEN RAISE EXCEPTION '%', pgv.t('quote.err_draft_delete_only'); END IF;

  DELETE FROM quote.estimate WHERE id = p_id::int AND tenant_id = current_setting('app.tenant_id', true);
  RETURN to_jsonb(v_row);
END;
$function$;
