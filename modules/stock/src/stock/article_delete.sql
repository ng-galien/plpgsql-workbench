CREATE OR REPLACE FUNCTION stock.article_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_row stock.article;
BEGIN
  UPDATE stock.article SET active = false, updated_at = now()
  WHERE id = p_id::int AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO v_row;

  RETURN to_jsonb(v_row);
END;
$function$;
