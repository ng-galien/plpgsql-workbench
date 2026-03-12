CREATE OR REPLACE FUNCTION expense.nav_items()
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN '[{"href":"/","label":"Dashboard","icon":"home"},{"href":"/notes","label":"Notes","icon":"file-text"},{"href":"/categories","label":"Catégories","icon":"tag"}]'::jsonb;
END;
$function$;
