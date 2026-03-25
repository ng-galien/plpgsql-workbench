CREATE OR REPLACE FUNCTION quote.post_ligne_supprimer(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_ligne_id int := (p_data->>'id')::int;
  v_redirect text;
  r record;
BEGIN
  SELECT l.devis_id, l.facture_id INTO r
    FROM quote.ligne l WHERE l.id = v_ligne_id;
  IF NOT FOUND THEN RAISE EXCEPTION '%', pgv.t('quote.err_not_found_ligne'); END IF;

  IF r.devis_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM quote.devis WHERE id = r.devis_id AND statut = 'brouillon') THEN
      RAISE EXCEPTION '%', pgv.t('quote.err_draft_lines_only');
    END IF;
    v_redirect := pgv.call_ref('get_devis', jsonb_build_object('p_id', r.devis_id));
  ELSE
    IF NOT EXISTS (SELECT 1 FROM quote.facture WHERE id = r.facture_id AND statut = 'brouillon') THEN
      RAISE EXCEPTION '%', pgv.t('quote.err_draft_lines_only');
    END IF;
    v_redirect := pgv.call_ref('get_facture', jsonb_build_object('p_id', r.facture_id));
  END IF;

  DELETE FROM quote.ligne WHERE id = v_ligne_id;

  RETURN pgv.toast(pgv.t('quote.toast_ligne_deleted'))
    || pgv.redirect(v_redirect);
END;
$function$;
