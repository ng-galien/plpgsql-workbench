CREATE OR REPLACE FUNCTION purchase._commande_form_body(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_cmd purchase.commande;
  v_fournisseur_name text;
  v_body text;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO v_cmd FROM purchase.commande WHERE id = p_id;
    SELECT name INTO v_fournisseur_name FROM crm.client WHERE id = v_cmd.fournisseur_id;
  END IF;

  v_body := '';
  IF p_id IS NOT NULL THEN
    v_body := format('<input type="hidden" name="p_id" value="%s">', p_id);
  END IF;

  v_body := v_body
    || pgv.select_search('p_fournisseur_id', pgv.t('purchase.field_fournisseur'),
         'fournisseur_options', pgv.t('purchase.field_search_fournisseur'),
         CASE WHEN p_id IS NOT NULL THEN v_cmd.fournisseur_id::text END,
         v_fournisseur_name)
    || pgv.input('p_objet', 'text', pgv.t('purchase.field_objet'), v_cmd.objet, true)
    || pgv.input('p_date_livraison', 'date', pgv.t('purchase.field_date_livraison'), v_cmd.date_livraison::text)
    || pgv.input('p_conditions_paiement', 'text', pgv.t('purchase.field_conditions'), v_cmd.conditions_paiement)
    || pgv.textarea('p_notes', pgv.t('purchase.field_notes'), v_cmd.notes);

  RETURN v_body;
END;
$function$;
