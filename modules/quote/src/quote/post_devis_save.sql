CREATE OR REPLACE FUNCTION quote.post_devis_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int;
  v_numero text;
BEGIN
  IF p_data->>'id' IS NOT NULL THEN
    v_id := (p_data->>'id')::int;
    IF NOT EXISTS (SELECT 1 FROM quote.devis WHERE id = v_id AND statut = 'brouillon') THEN
      RAISE EXCEPTION '%', pgv.t('quote.err_brouillon_only');
    END IF;
    UPDATE quote.devis SET
      client_id = (p_data->>'client_id')::int,
      objet = p_data->>'objet',
      validite_jours = coalesce((p_data->>'validite_jours')::int, 30),
      notes = coalesce(p_data->>'notes', '')
    WHERE id = v_id;
  ELSE
    v_numero := quote._next_numero('DEV');
    INSERT INTO quote.devis (numero, client_id, objet, validite_jours, notes)
    VALUES (
      v_numero,
      (p_data->>'client_id')::int,
      p_data->>'objet',
      coalesce((p_data->>'validite_jours')::int, 30),
      coalesce(p_data->>'notes', '')
    ) RETURNING id INTO v_id;
  END IF;

  RETURN pgv.toast(pgv.t('quote.toast_devis_saved'))
    || pgv.redirect(pgv.call_ref('get_devis', jsonb_build_object('p_id', v_id)));
END;
$function$;
