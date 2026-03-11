CREATE OR REPLACE FUNCTION cad.get_drawing_bom(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cad.drawing WHERE id = p_id) THEN
    RETURN pgv.error('404', 'Dessin non trouvé');
  END IF;

  RETURN cad.bill_of_materials(p_id)
    || '<p><a href="' || pgv.call_ref('get_drawing', jsonb_build_object('p_id', p_id)) || '">Retour au plan</a></p>';
END;
$function$;
