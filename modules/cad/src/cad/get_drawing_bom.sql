CREATE OR REPLACE FUNCTION cad.get_drawing_bom(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cad.drawing WHERE id = p_id) THEN
    RETURN pgv.error('404', pgv.t('cad.err_not_found'));
  END IF;

  RETURN '<p>'
    || '<a href="' || pgv.call_ref('get_drawing', jsonb_build_object('p_id', p_id)) || '">' || pgv.t('cad.vue_2d') || '</a>'
    || ' | <a href="' || pgv.call_ref('get_drawing_3d', jsonb_build_object('p_id', p_id)) || '">' || pgv.t('cad.vue_3d') || '</a>'
    || ' | <strong>' || pgv.t('cad.liste_debit') || '</strong>'
    || '</p>'
    || '<pre>' || cad.bill_of_materials(p_id) || '</pre>';
END;
$function$;
