CREATE OR REPLACE FUNCTION purchase.post_facture_valider(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_data->>'p_id')::int;
BEGIN
  UPDATE purchase.facture_fournisseur SET statut = 'validee'
   WHERE id = v_id AND statut = 'recue';

  IF NOT FOUND THEN
    RETURN '<template data-toast="error">Facture introuvable ou déjà validée</template>';
  END IF;

  RETURN format('<template data-toast="success">Facture validée</template><template data-redirect="%s"></template>',
    pgv.call_ref('get_facture_fournisseur', jsonb_build_object('p_id', v_id)));
END;
$function$;
