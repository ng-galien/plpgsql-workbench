CREATE OR REPLACE FUNCTION quote.post_devis_supprimer(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_data->>'id')::int;
  v_statut text;
BEGIN
  SELECT statut INTO v_statut FROM quote.devis WHERE id = v_id;
  IF v_statut IS NULL THEN RAISE EXCEPTION 'Devis introuvable'; END IF;
  IF v_statut <> 'brouillon' THEN RAISE EXCEPTION 'Seuls les brouillons peuvent être supprimés'; END IF;

  DELETE FROM quote.devis WHERE id = v_id;

  RETURN '<template data-toast="success">Devis supprimé</template>'
    || '<template data-redirect="' || pgv.call_ref('get_devis') || '"></template>';
END;
$function$;
