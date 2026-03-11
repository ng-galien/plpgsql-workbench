CREATE OR REPLACE FUNCTION cad_qa.get_drawing_bom(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cad.drawing WHERE id = p_id) THEN
    RETURN pgv.error('404', 'Dessin non trouvé');
  END IF;

  RETURN '<p>'
    || '<a href="' || pgv.call_ref('get_drawing', jsonb_build_object('p_id', p_id)) || '">Vue 2D</a>'
    || ' | <a href="' || pgv.call_ref('get_drawing_3d', jsonb_build_object('p_id', p_id)) || '">Vue 3D</a>'
    || ' | <strong>Liste de débit</strong>'
    || '</p>'
    || '<pre>' || cad.bill_of_materials(p_id) || '</pre>';
END;
$function$;
