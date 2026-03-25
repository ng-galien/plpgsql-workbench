CREATE OR REPLACE FUNCTION cad.post_shape_delete(shape_id integer, drawing_id integer)
 RETURNS "text/html"
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF shape_id IS NULL THEN
    RETURN pgv.toast(pgv.t('cad.err_shape_id_required'), 'error');
  END IF;

  PERFORM cad.delete_shape(shape_id);

  RETURN pgv.toast(format(pgv.t('cad.toast_shape_deleted'), shape_id))
    || pgv.redirect(format('/drawing?p_id=%s', drawing_id));
END;
$function$;
