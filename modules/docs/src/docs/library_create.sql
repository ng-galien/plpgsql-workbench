CREATE OR REPLACE FUNCTION docs.library_create(p_name text, p_description text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id text;
BEGIN
  INSERT INTO docs.library (name, description)
  VALUES (p_name, p_description)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;
