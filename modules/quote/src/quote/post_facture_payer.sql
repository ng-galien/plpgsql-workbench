CREATE OR REPLACE FUNCTION quote.post_facture_payer(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_data->>'id')::int;
  v_statut text;
BEGIN
  SELECT statut INTO v_statut FROM quote.facture WHERE id = v_id;
  IF v_statut IS NULL THEN RAISE EXCEPTION 'Facture introuvable'; END IF;
  IF v_statut <> 'envoyee' THEN RAISE EXCEPTION 'Transition invalide: % -> payee', v_statut; END IF;

  UPDATE quote.facture SET statut = 'payee', paid_at = now() WHERE id = v_id;

  RETURN '<template data-toast="success">Facture marquée comme payée</template>'
    || '<template data-redirect="' || pgv.call_ref('get_facture', jsonb_build_object('p_id', v_id)) || '"></template>';
END;
$function$;
