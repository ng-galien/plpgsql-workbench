CREATE OR REPLACE FUNCTION cad.page_drawing_bom(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_drawing cad.drawing;
BEGIN
  SELECT * INTO v_drawing FROM cad.drawing WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN pgv.error('404', 'Dessin non trouvé');
  END IF;

  RETURN cad.bill_of_materials(p_id)
    || format('<p><a href="/drawing/%s">Retour au plan</a></p>', p_id);
END;
$function$;
