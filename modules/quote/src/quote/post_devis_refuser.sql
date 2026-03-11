CREATE OR REPLACE FUNCTION quote.post_devis_refuser(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_data->>'id')::int;
  v_statut text;
BEGIN
  SELECT statut INTO v_statut FROM quote.devis WHERE id = v_id;
  IF v_statut IS NULL THEN RAISE EXCEPTION 'Devis introuvable'; END IF;
  IF v_statut <> 'envoye' THEN RAISE EXCEPTION 'Transition invalide: % -> refuse', v_statut; END IF;

  UPDATE quote.devis SET statut = 'refuse' WHERE id = v_id;

  RETURN '<template data-toast="success">Devis refusé</template>'
    || '<template data-redirect="' || pgv.call_ref('get_devis', jsonb_build_object('p_id', v_id)) || '"></template>';
END;
$function$;
