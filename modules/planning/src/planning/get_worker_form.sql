CREATE OR REPLACE FUNCTION planning.get_worker_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE v planning.worker; v_body text;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO v FROM planning.worker WHERE id = p_id;
    IF NOT FOUND THEN RETURN pgv.error('404', pgv.t('planning.err_worker_not_found')); END IF;
  END IF;
  v_body := pgv.form('post_worker_save', planning._worker_form_inputs(p_id, v.name, v.role, v.phone, v.color, v.active), pgv.t('planning.btn_save'));
  RETURN v_body;
END;
$function$;
