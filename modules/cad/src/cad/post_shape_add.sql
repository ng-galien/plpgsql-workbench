CREATE OR REPLACE FUNCTION cad.post_shape_add(drawing_id integer, layer_id integer, type text, geometry text DEFAULT '{}'::text, props text DEFAULT '{}'::text, label text DEFAULT NULL::text)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_geometry jsonb;
  v_props jsonb;
  v_shape_id int;
BEGIN
  IF layer_id IS NULL OR type IS NULL THEN
    RETURN pgv.toast(pgv.t('cad.err_layer_type_required'), 'error');
  END IF;

  BEGIN
    v_geometry := geometry::jsonb;
  EXCEPTION WHEN OTHERS THEN
    RETURN pgv.toast(pgv.t('cad.err_geometry_invalid'), 'error');
  END;

  BEGIN
    v_props := props::jsonb;
  EXCEPTION WHEN OTHERS THEN
    RETURN pgv.toast(pgv.t('cad.err_props_invalid'), 'error');
  END;

  v_shape_id := cad.add_shape(drawing_id, layer_id, type, v_geometry, v_props, nullif(trim(COALESCE(label, '')), ''));

  RETURN pgv.toast(format(pgv.t('cad.toast_shape_added'), v_shape_id))
    || pgv.redirect(format('/drawing?p_id=%s', drawing_id));
END;
$function$;
