CREATE OR REPLACE FUNCTION expense.note_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(n) || jsonb_build_object(
        'nb_lignes', COALESCE(l.cnt, 0),
        'total_ht', COALESCE(l.sum_ht, 0),
        'total_ttc', COALESCE(l.sum_ttc, 0)
      )
      FROM expense.note n
      LEFT JOIN LATERAL (
        SELECT count(*) as cnt, sum(montant_ht) as sum_ht, sum(montant_ttc) as sum_ttc
        FROM expense.ligne WHERE note_id = n.id
      ) l ON true
      ORDER BY n.updated_at DESC;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(n) || jsonb_build_object(
        ''nb_lignes'', COALESCE(l.cnt, 0),
        ''total_ht'', COALESCE(l.sum_ht, 0),
        ''total_ttc'', COALESCE(l.sum_ttc, 0)
      )
      FROM expense.note n
      LEFT JOIN LATERAL (
        SELECT count(*) as cnt, sum(montant_ht) as sum_ht, sum(montant_ttc) as sum_ttc
        FROM expense.ligne WHERE note_id = n.id
      ) l ON true
      WHERE ' || pgv.rsql_to_where(p_filter, 'expense', 'note')
      || ' ORDER BY n.updated_at DESC';
  END IF;
END;
$function$;
