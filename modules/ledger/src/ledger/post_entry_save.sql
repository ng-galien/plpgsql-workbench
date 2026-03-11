CREATE OR REPLACE FUNCTION ledger.post_entry_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id integer;
BEGIN
  IF p_data->>'id' IS NOT NULL THEN
    v_id := (p_data->>'id')::integer;
    IF NOT EXISTS (SELECT 1 FROM ledger.journal_entry WHERE id = v_id AND NOT posted) THEN
      RAISE EXCEPTION 'Seuls les brouillons sont modifiables';
    END IF;
    UPDATE ledger.journal_entry SET
      entry_date = (p_data->>'entry_date')::date,
      reference = p_data->>'reference',
      description = p_data->>'description'
    WHERE id = v_id;
  ELSE
    INSERT INTO ledger.journal_entry (entry_date, reference, description)
    VALUES (
      coalesce((p_data->>'entry_date')::date, CURRENT_DATE),
      p_data->>'reference',
      p_data->>'description'
    ) RETURNING id INTO v_id;
  END IF;

  RETURN '<template data-toast="success">Écriture enregistrée</template>'
    || '<template data-redirect="' || pgv.call_ref('get_entry', jsonb_build_object('p_id', v_id)) || '"></template>';
END;
$function$;
