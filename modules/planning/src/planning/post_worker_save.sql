CREATE OR REPLACE FUNCTION planning.post_worker_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_id int := NULLIF(p_data->>'id', '')::int; v_name text := trim(p_data->>'name');
BEGIN
  IF v_name IS NULL OR v_name = '' THEN RETURN pgv.toast(pgv.t('planning.err_name_required'), 'error'); END IF;
  IF v_id IS NOT NULL THEN
    UPDATE planning.worker SET name = v_name, role = COALESCE(trim(p_data->>'role'), role), phone = COALESCE(trim(p_data->>'phone'), phone), color = COALESCE(NULLIF(trim(p_data->>'color'), ''), color), active = COALESCE((p_data->>'active')::boolean, active) WHERE id = v_id;
  ELSE
    INSERT INTO planning.worker (name, role, phone, color, active) VALUES (v_name, COALESCE(trim(p_data->>'role'), ''), trim(p_data->>'phone'), COALESCE(NULLIF(trim(p_data->>'color'), ''), '#3b82f6'), COALESCE((p_data->>'active')::boolean, true)) RETURNING id INTO v_id;
  END IF;
  RETURN pgv.toast(pgv.t('planning.toast_worker_saved')) || pgv.redirect(pgv.call_ref('get_worker', jsonb_build_object('p_id', v_id)));
END;
$function$;
