CREATE OR REPLACE FUNCTION pgv.ui_currency(p_amount numeric, p_currency text DEFAULT 'EUR'::text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('type', 'currency', 'amount', p_amount, 'currency', p_currency);
$function$;
