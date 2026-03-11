CREATE OR REPLACE FUNCTION ledger.post_line_delete(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id integer;
  v_entry_id integer;
BEGIN
  v_id := (p_data->>'id')::integer;
  v_entry_id := (p_data->>'entry_id')::integer;

  IF NOT EXISTS (SELECT 1 FROM ledger.journal_entry WHERE id = v_entry_id AND NOT posted) THEN
    RAISE EXCEPTION 'Écriture introuvable ou déjà validée';
  END IF;

  DELETE FROM ledger.entry_line WHERE id = v_id AND journal_entry_id = v_entry_id;

  RETURN '<template data-toast="success">Ligne supprimée</template>'
    || '<template data-redirect="' || pgv.call_ref('get_entry', jsonb_build_object('p_id', v_entry_id)) || '"></template>';
END;
$function$;
