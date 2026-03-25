CREATE OR REPLACE FUNCTION quote.post_line_item_delete(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_line_id int := (p_data->>'id')::int;
  v_redirect text;
  r record;
BEGIN
  SELECT l.estimate_id, l.invoice_id INTO r
    FROM quote.line_item l WHERE l.id = v_line_id;
  IF NOT FOUND THEN RAISE EXCEPTION '%', pgv.t('quote.err_not_found_line'); END IF;

  IF r.estimate_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM quote.estimate WHERE id = r.estimate_id AND status = 'draft') THEN
      RAISE EXCEPTION '%', pgv.t('quote.err_draft_lines_only');
    END IF;
    v_redirect := pgv.call_ref('get_estimate', jsonb_build_object('p_id', r.estimate_id));
  ELSE
    IF NOT EXISTS (SELECT 1 FROM quote.invoice WHERE id = r.invoice_id AND status = 'draft') THEN
      RAISE EXCEPTION '%', pgv.t('quote.err_draft_lines_only');
    END IF;
    v_redirect := pgv.call_ref('get_invoice', jsonb_build_object('p_id', r.invoice_id));
  END IF;

  DELETE FROM quote.line_item WHERE id = v_line_id;

  RETURN pgv.toast(pgv.t('quote.toast_line_deleted'))
    || pgv.redirect(v_redirect);
END;
$function$;
