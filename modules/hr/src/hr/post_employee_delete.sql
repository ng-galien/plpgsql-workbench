CREATE OR REPLACE FUNCTION hr.post_employee_delete(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_data->>'id')::int;
BEGIN
  DELETE FROM hr.employee WHERE id = v_id;
  IF NOT FOUND THEN
    RETURN pgv.toast('Salarié introuvable.', 'error');
  END IF;

  RETURN pgv.toast('Salarié supprimé.') || pgv.redirect(pgv.call_ref('get_index'));
END;
$function$;
