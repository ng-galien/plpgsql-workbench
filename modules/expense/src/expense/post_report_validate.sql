CREATE OR REPLACE FUNCTION expense.post_report_validate(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_id int := (p_params->>'id')::int;
BEGIN
  IF v_id IS NULL THEN RETURN pgv.toast(pgv.t('expense.err_id_required'), 'error'); END IF;
  UPDATE expense.expense_report SET status = 'validated', updated_at = now() WHERE id = v_id AND status = 'submitted';
  IF NOT FOUND THEN RETURN pgv.toast(pgv.t('expense.err_not_submitted'), 'error'); END IF;
  RETURN pgv.toast(pgv.t('expense.toast_note_validated')) || pgv.redirect('/expense_report?p_id=' || v_id);
END;
$function$;
