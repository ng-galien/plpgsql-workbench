CREATE OR REPLACE FUNCTION quote.post_ligne_ajouter(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_devis_id int;
  v_facture_id int;
  v_redirect text;
BEGIN
  v_devis_id := (p_data->>'devis_id')::int;
  v_facture_id := (p_data->>'facture_id')::int;

  -- Vérifier que le parent est brouillon
  IF v_devis_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM quote.devis WHERE id = v_devis_id AND statut = 'brouillon') THEN
      RAISE EXCEPTION 'Lignes modifiables uniquement sur un brouillon';
    END IF;
    v_redirect := pgv.call_ref('get_devis', jsonb_build_object('p_id', v_devis_id));
  ELSIF v_facture_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM quote.facture WHERE id = v_facture_id AND statut = 'brouillon') THEN
      RAISE EXCEPTION 'Lignes modifiables uniquement sur un brouillon';
    END IF;
    v_redirect := pgv.call_ref('get_facture', jsonb_build_object('p_id', v_facture_id));
  ELSE
    RAISE EXCEPTION 'devis_id ou facture_id requis';
  END IF;

  INSERT INTO quote.ligne (devis_id, facture_id, description, quantite, unite, prix_unitaire, tva_rate)
  VALUES (
    v_devis_id,
    v_facture_id,
    p_data->>'description',
    coalesce((p_data->>'quantite')::numeric, 1),
    coalesce(p_data->>'unite', 'u'),
    (p_data->>'prix_unitaire')::numeric,
    coalesce((p_data->>'tva_rate')::numeric, 20.00)
  );

  RETURN '<template data-toast="success">Ligne ajoutée</template>'
    || '<template data-redirect="' || v_redirect || '"></template>';
END;
$function$;
