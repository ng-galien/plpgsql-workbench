CREATE OR REPLACE FUNCTION cad_qa.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT jsonb_build_array(
    jsonb_build_object('href', pgv.call_ref('get_index'), 'label', 'Accueil'),
    jsonb_build_object('href', pgv.call_ref('get_drawing'), 'label', '2D'),
    jsonb_build_object('href', pgv.call_ref('get_drawing_3d'), 'label', '3D')
  );
$function$;
