CREATE OR REPLACE FUNCTION expense.post_report_submit(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_id int := (p_params->>'id')::int; v_cnt int;
BEGIN
  IF v_id IS NULL THEN RETURN pgv.toast(pgv.t('expense.err_id_required'), 'error'); END IF;
  SELECT count(*)::int INTO v_cnt FROM expense.line WHERE note_id = v_id;
  IF v_cnt = 0 THEN RETURN pgv.toast(pgv.t('expense.err_no_lines'), 'error'); END IF;
  UPDATE expense.expense_report SET status = 'submitted', updated_at = now() WHERE id = v_id AND status = 'draft';
  IF NOT FOUND THEN RETURN pgv.toast(pgv.t('expense.err_not_draft_submit'), 'error'); END IF;
  RETURN pgv.toast(pgv.t('expense.toast_note_submitted')) || pgv.redirect('/expense_report?p_id=' || v_id);
END;
$function$;
