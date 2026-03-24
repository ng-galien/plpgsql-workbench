CREATE OR REPLACE FUNCTION expense.note_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN (
    SELECT to_jsonb(n) || jsonb_build_object(
      'lignes', COALESCE((
        SELECT jsonb_agg(to_jsonb(lg) || jsonb_build_object('categorie_nom', c.nom) ORDER BY lg.date_depense)
        FROM expense.ligne lg
        LEFT JOIN expense.categorie c ON c.id = lg.categorie_id
        WHERE lg.note_id = n.id
      ), '[]'::jsonb),
      'total_ht', COALESCE((SELECT sum(montant_ht) FROM expense.ligne WHERE note_id = n.id), 0),
      'total_ttc', COALESCE((SELECT sum(montant_ttc) FROM expense.ligne WHERE note_id = n.id), 0)
    )
    FROM expense.note n
    WHERE n.id = p_id::int OR n.reference = p_id
  );
END;
$function$;
