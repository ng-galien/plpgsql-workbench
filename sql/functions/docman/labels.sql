CREATE OR REPLACE FUNCTION docman.labels(p_kind text DEFAULT NULL::text, p_parent_id integer DEFAULT NULL::integer)
 RETURNS TABLE(id integer, name text, kind text, parent_id integer, description text, aliases text[])
 LANGUAGE sql
 STABLE
AS $function$
  SELECT l.id, l.name, l.kind, l.parent_id, l.description, l.aliases
  FROM docman.label l
  WHERE (p_kind IS NULL OR l.kind = p_kind)
    AND (p_parent_id IS NULL OR l.parent_id = p_parent_id)
  ORDER BY l.kind, l.parent_id NULLS FIRST, l.name;
$function$;
