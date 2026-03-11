CREATE OR REPLACE FUNCTION cad.get_drawing_3d(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cad.drawing WHERE id = p_id) THEN
    RETURN pgv.error('404', 'Dessin non trouvé');
  END IF;

  RETURN cad.fragment_viewer(p_id);
END;
$function$;
