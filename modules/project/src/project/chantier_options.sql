CREATE OR REPLACE FUNCTION project.chantier_options(p_search text DEFAULT ''::text)
 RETURNS TABLE(value text, label text, detail text)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
    SELECT c.id::text,
           c.numero || ' — ' || pgv.esc(c.objet),
           project._statut_badge(c.statut)
      FROM project.chantier c
     WHERE p_search = ''
        OR c.numero ILIKE '%' || p_search || '%'
        OR c.objet  ILIKE '%' || p_search || '%'
     ORDER BY c.updated_at DESC NULLS LAST
     LIMIT 20;
END;
$function$;
