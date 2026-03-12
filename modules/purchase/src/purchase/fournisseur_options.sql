CREATE OR REPLACE FUNCTION purchase.fournisseur_options(p_search text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  SELECT coalesce(jsonb_agg(row_j ORDER BY row_j->>'label'), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT jsonb_build_object(
      'value', id::text,
      'label', name,
      'detail', coalesce(email, phone, '')
    ) AS row_j
    FROM crm.client
    WHERE active
      AND (p_search = '' OR name ILIKE '%' || p_search || '%' OR email ILIKE '%' || p_search || '%')
    LIMIT 30
  ) sub;

  RETURN coalesce(v_result, '[]'::jsonb);
END;
$function$;
