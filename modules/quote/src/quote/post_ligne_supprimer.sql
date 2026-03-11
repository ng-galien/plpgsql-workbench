CREATE OR REPLACE FUNCTION quote.post_ligne_supprimer(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_ligne_id int := (p_data->>'id')::int;
  v_redirect text;
  r record;
BEGIN
  SELECT l.devis_id, l.facture_id INTO r
    FROM quote.ligne l WHERE l.id = v_ligne_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Ligne introuvable'; END IF;

  -- Vérifier que le parent est brouillon
  IF r.devis_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM quote.devis WHERE id = r.devis_id AND statut = 'brouillon') THEN
      RAISE EXCEPTION 'Lignes modifiables uniquement sur un brouillon';
    END IF;
    v_redirect := pgv.call_ref('get_devis', jsonb_build_object('p_id', r.devis_id));
  ELSE
    IF NOT EXISTS (SELECT 1 FROM quote.facture WHERE id = r.facture_id AND statut = 'brouillon') THEN
      RAISE EXCEPTION 'Lignes modifiables uniquement sur un brouillon';
    END IF;
    v_redirect := pgv.call_ref('get_facture', jsonb_build_object('p_id', r.facture_id));
  END IF;

  DELETE FROM quote.ligne WHERE id = v_ligne_id;

  RETURN '<template data-toast="success">Ligne supprimée</template>'
    || '<template data-redirect="' || v_redirect || '"></template>';
END;
$function$;
