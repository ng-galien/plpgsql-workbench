CREATE OR REPLACE FUNCTION quote.post_facture_envoyer(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_data->>'id')::int;
  v_statut text;
BEGIN
  SELECT statut INTO v_statut FROM quote.facture WHERE id = v_id;
  IF v_statut IS NULL THEN RAISE EXCEPTION 'Facture introuvable'; END IF;
  IF v_statut <> 'brouillon' THEN RAISE EXCEPTION 'Transition invalide: % -> envoyee', v_statut; END IF;

  UPDATE quote.facture SET statut = 'envoyee' WHERE id = v_id;

  RETURN '<template data-toast="success">Facture envoyée</template>'
    || '<template data-redirect="' || pgv.call_ref('get_facture', jsonb_build_object('p_id', v_id)) || '"></template>';
END;
$function$;
