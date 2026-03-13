CREATE OR REPLACE FUNCTION purchase.get_commande_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_title text;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT pgv.t('purchase.title_modifier_commande') || ' ' || numero
      INTO v_title
      FROM purchase.commande WHERE id = p_id;
  ELSE
    v_title := pgv.t('purchase.title_nouvelle_commande');
  END IF;

  RETURN '<h3>' || pgv.esc(v_title) || '</h3>'
    || pgv.form('post_commande_save', purchase._commande_form_body(p_id), pgv.t('purchase.btn_enregistrer'));
END;
$function$;
