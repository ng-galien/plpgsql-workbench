CREATE OR REPLACE FUNCTION cad.post_drawing_add(name text, dimension text DEFAULT '2d'::text)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_dim text;
BEGIN
  IF name IS NULL OR trim(name) = '' THEN
    RETURN pgv.toast(pgv.t('cad.err_name_required'), 'error');
  END IF;

  v_dim := CASE WHEN dimension = '3d' THEN '3d' ELSE '2d' END;

  INSERT INTO cad.drawing (name, dimension) VALUES (trim(name), v_dim) RETURNING id INTO v_id;

  INSERT INTO cad.layer (drawing_id, name, color, stroke_width)
  VALUES (v_id, 'Structure', '#333333', 1.5);

  RETURN pgv.redirect(format('/drawing?p_id=%s', v_id));
END;
$function$;
