CREATE OR REPLACE FUNCTION docman.entities(p_kind text DEFAULT NULL::text)
 RETURNS TABLE(id integer, kind text, name text, aliases text[], metadata jsonb)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT e.id, e.kind, e.name, e.aliases, e.metadata
  FROM docman.entity e
  WHERE p_kind IS NULL OR e.kind = p_kind
  ORDER BY e.kind, e.name;
$function$;
