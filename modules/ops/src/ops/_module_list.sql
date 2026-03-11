CREATE OR REPLACE FUNCTION ops._module_list()
 RETURNS TABLE(module text)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT n.nspname::text AS module
    FROM pg_namespace n
    JOIN pg_proc p ON p.pronamespace = n.oid AND p.proname = 'nav_items'
   WHERE n.nspname NOT IN ('pgv', 'ops')
     AND n.nspname NOT LIKE '%\_qa' ESCAPE '\'
   ORDER BY n.nspname;
$function$;
