CREATE OR REPLACE FUNCTION planning.intervenant_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(i) || jsonb_build_object(
        'nb_evt_actifs', (SELECT count(*)::int FROM planning.affectation a
                          JOIN planning.evenement e ON e.id = a.evenement_id
                          WHERE a.intervenant_id = i.id AND e.date_fin >= current_date)
      )
      FROM planning.intervenant i
      WHERE i.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY i.actif DESC, i.nom;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(i) || jsonb_build_object(
        ''nb_evt_actifs'', (SELECT count(*)::int FROM planning.affectation a
                            JOIN planning.evenement e ON e.id = a.evenement_id
                            WHERE a.intervenant_id = i.id AND e.date_fin >= current_date)
      )
      FROM planning.intervenant i
      WHERE i.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
      || ' AND ' || pgv.rsql_to_where(p_filter, 'planning', 'intervenant')
      || ' ORDER BY i.actif DESC, i.nom';
  END IF;
END;
$function$;
