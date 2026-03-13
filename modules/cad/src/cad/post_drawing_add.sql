CREATE OR REPLACE FUNCTION cad.post_drawing_add(name text)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
BEGIN
  IF name IS NULL OR trim(name) = '' THEN
    RETURN pgv.toast(pgv.t('cad.err_name_required'), 'error');
  END IF;

  INSERT INTO cad.drawing (name) VALUES (trim(name)) RETURNING id INTO v_id;

  INSERT INTO cad.layer (drawing_id, name, color, stroke_width)
  VALUES (v_id, 'Structure', '#333333', 1.5);

  RETURN pgv.redirect(format('/drawing?p_id=%s', v_id));
END;
$function$;
