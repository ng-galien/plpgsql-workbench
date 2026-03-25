CREATE OR REPLACE FUNCTION quote.post_facture_relancer(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_data->>'p_id')::int;
  v_statut text;
  v_days int;
BEGIN
  SELECT statut, extract(day FROM now() - created_at)::int
    INTO v_statut, v_days
    FROM quote.facture WHERE id = v_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION '%', pgv.t('quote.err_not_found_facture');
  END IF;

  IF v_statut <> 'envoyee' THEN
    RAISE EXCEPTION 'Seule une facture envoyee peut etre relancee (statut actuel: %)', v_statut;
  END IF;

  IF v_days <= 30 THEN
    RAISE EXCEPTION 'Relance possible uniquement apres 30 jours (actuellement: % jours)', v_days;
  END IF;

  UPDATE quote.facture
     SET statut = 'relance',
         notes = notes || E'\n[Relance ' || to_char(now(), 'DD/MM/YYYY') || ']'
   WHERE id = v_id;

  RETURN pgv.toast(pgv.t('quote.toast_facture_relance'))
      || pgv.redirect('/quote/facture?p_id=' || v_id);
END;
$function$;
