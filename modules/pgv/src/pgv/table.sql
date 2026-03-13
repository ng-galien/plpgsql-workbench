CREATE OR REPLACE FUNCTION pgv."table"(p_config jsonb)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  RETURN '<div x-data="pgvTable" data-config="' || pgv.esc(p_config::text) || '"></div>';
END;
$function$;
