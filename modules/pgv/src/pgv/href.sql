CREATE OR REPLACE FUNCTION pgv.href(p_url text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE
    WHEN left(p_url, 8) = 'https://' THEN p_url
    WHEN left(p_url, 7) = 'http://'  THEN p_url
    WHEN left(p_url, 2) = '//'       THEN p_url
    WHEN left(p_url, 7) = 'mailto:'  THEN p_url
    WHEN left(p_url, 4) = 'tel:'     THEN p_url
    ELSE NULL
  END;
$function$;
