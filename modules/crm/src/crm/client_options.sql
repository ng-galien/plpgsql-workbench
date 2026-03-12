CREATE OR REPLACE FUNCTION crm.client_options(p_search text DEFAULT NULL::text)
 RETURNS TABLE(value text, label text, detail text)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT
    c.id::text,
    c.name,
    concat_ws(' / ',
      nullif(c.city, ''),
      nullif(c.email, '')
    )
  FROM crm.client c
  WHERE c.active
    AND (p_search IS NULL OR p_search = ''
         OR c.name ILIKE '%' || p_search || '%'
         OR c.email ILIKE '%' || p_search || '%'
         OR c.city ILIKE '%' || p_search || '%')
  ORDER BY c.name
  LIMIT 20;
$function$;
