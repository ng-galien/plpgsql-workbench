CREATE OR REPLACE FUNCTION expense.note_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
  v_statut text;
  v_id int;
  v_nb_lignes int;
  v_actions jsonb := '[]'::jsonb;
BEGIN
  v_result := (
    SELECT to_jsonb(n) || jsonb_build_object(
      'lignes', COALESCE((
        SELECT jsonb_agg(to_jsonb(lg) || jsonb_build_object('categorie_nom', c.nom) ORDER BY lg.date_depense)
        FROM expense.ligne lg
        LEFT JOIN expense.categorie c ON c.id = lg.categorie_id
        WHERE lg.note_id = n.id
      ), '[]'::jsonb),
      'total_ht', COALESCE((SELECT sum(montant_ht) FROM expense.ligne WHERE note_id = n.id), 0),
      'total_ttc', COALESCE((SELECT sum(montant_ttc) FROM expense.ligne WHERE note_id = n.id), 0),
      'nb_lignes', (SELECT count(*) FROM expense.ligne WHERE note_id = n.id)::int
    )
    FROM expense.note n
    WHERE n.id = p_id::int OR n.reference = p_id
  );

  IF v_result IS NULL THEN
    RETURN NULL;
  END IF;

  v_statut := v_result->>'statut';
  v_id := (v_result->>'id')::int;
  v_nb_lignes := (v_result->>'nb_lignes')::int;

  -- HATEOAS actions based on state
  CASE v_statut
    WHEN 'brouillon' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'edit', 'uri', 'expense://note/' || v_id || '/edit'),
        jsonb_build_object('method', 'add_ligne', 'uri', 'expense://note/' || v_id || '/add_ligne')
      );
      IF v_nb_lignes > 0 THEN
        v_actions := v_actions || jsonb_build_array(
          jsonb_build_object('method', 'submit', 'uri', 'expense://note/' || v_id || '/submit')
        );
      END IF;
      v_actions := v_actions || jsonb_build_array(
        jsonb_build_object('method', 'delete', 'uri', 'expense://note/' || v_id || '/delete')
      );
    WHEN 'soumise' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'validate', 'uri', 'expense://note/' || v_id || '/validate'),
        jsonb_build_object('method', 'reject', 'uri', 'expense://note/' || v_id || '/reject')
      );
    WHEN 'validee' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'reimburse', 'uri', 'expense://note/' || v_id || '/reimburse')
      );
    WHEN 'remboursee' THEN
      v_actions := '[]'::jsonb;
    WHEN 'rejetee' THEN
      v_actions := '[]'::jsonb;
  END CASE;

  RETURN v_result || jsonb_build_object('actions', v_actions);
END;
$function$;
