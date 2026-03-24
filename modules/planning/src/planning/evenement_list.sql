CREATE OR REPLACE FUNCTION planning.evenement_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(e) || jsonb_build_object(
        'chantier_numero', ch.numero,
        'intervenants', COALESCE((
          SELECT jsonb_agg(jsonb_build_object('id', i.id, 'nom', i.nom, 'couleur', i.couleur) ORDER BY i.nom)
          FROM planning.affectation a JOIN planning.intervenant i ON i.id = a.intervenant_id
          WHERE a.evenement_id = e.id
        ), '[]'::jsonb)
      )
      FROM planning.evenement e
      LEFT JOIN project.chantier ch ON ch.id = e.chantier_id
      WHERE e.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY e.date_debut DESC;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(e) || jsonb_build_object(
        ''chantier_numero'', ch.numero,
        ''intervenants'', COALESCE((
          SELECT jsonb_agg(jsonb_build_object(''id'', i.id, ''nom'', i.nom, ''couleur'', i.couleur) ORDER BY i.nom)
          FROM planning.affectation a JOIN planning.intervenant i ON i.id = a.intervenant_id
          WHERE a.evenement_id = e.id
        ), ''[]''::jsonb)
      )
      FROM planning.evenement e
      LEFT JOIN project.chantier ch ON ch.id = e.chantier_id
      WHERE e.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
      || ' AND ' || pgv.rsql_to_where(p_filter, 'planning', 'evenement')
      || ' ORDER BY e.date_debut DESC';
  END IF;
END;
$function$;
