CREATE OR REPLACE FUNCTION pgv.href(p_url text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  IF left(p_url, 8) = 'https://' THEN RETURN p_url; END IF;
  IF left(p_url, 7) = 'http://'  THEN RETURN p_url; END IF;
  IF left(p_url, 2) = '//'       THEN RETURN p_url; END IF;
  IF left(p_url, 7) = 'mailto:'  THEN RETURN p_url; END IF;
  IF left(p_url, 4) = 'tel:'     THEN RETURN p_url; END IF;

  RAISE EXCEPTION 'pgv.href() is for external URLs only — use a raw href="/..." for internal links, or pgv.call_ref() for cross-module refs. Got: %', p_url;
END;
$function$;
