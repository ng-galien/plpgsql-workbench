CREATE OR REPLACE FUNCTION quote.post_facture_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_numero text;
BEGIN
  IF p_data->>'id' IS NOT NULL THEN
    v_id := (p_data->>'id')::int;
    IF NOT EXISTS (SELECT 1 FROM quote.facture WHERE id = v_id AND statut = 'brouillon') THEN
      RAISE EXCEPTION 'Seuls les brouillons sont modifiables';
    END IF;
    UPDATE quote.facture SET
      client_id = (p_data->>'client_id')::int,
      objet = p_data->>'objet',
      notes = coalesce(p_data->>'notes', '')
    WHERE id = v_id;
  ELSE
    v_numero := quote._next_numero('FAC');
    INSERT INTO quote.facture (numero, client_id, objet, notes)
    VALUES (
      v_numero,
      (p_data->>'client_id')::int,
      p_data->>'objet',
      coalesce(p_data->>'notes', '')
    ) RETURNING id INTO v_id;
  END IF;

  RETURN '<template data-toast="success">Facture enregistrée</template>'
    || '<template data-redirect="' || pgv.call_ref('get_facture', jsonb_build_object('p_id', v_id)) || '"></template>';
END;
$function$;
