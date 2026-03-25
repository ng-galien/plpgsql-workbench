CREATE OR REPLACE FUNCTION expense.post_report_create(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_params->>'id')::int;
  v_author text := p_params->>'author';
  v_start_date date := (p_params->>'start_date')::date;
  v_end_date date := (p_params->>'end_date')::date;
  v_comment text := p_params->>'comment';
  v_report_id int;
BEGIN
  IF v_author IS NULL OR v_start_date IS NULL OR v_end_date IS NULL THEN
    RETURN pgv.toast(pgv.t('expense.err_fields_required'), 'error');
  END IF;
  IF v_end_date < v_start_date THEN
    RETURN pgv.toast(pgv.t('expense.err_date_order'), 'error');
  END IF;
  IF v_id IS NOT NULL THEN
    UPDATE expense.expense_report SET author = v_author, start_date = v_start_date, end_date = v_end_date, comment = v_comment, updated_at = now()
    WHERE id = v_id AND status = 'draft';
    IF NOT FOUND THEN RETURN pgv.toast(pgv.t('expense.err_note_not_modifiable'), 'error'); END IF;
    v_report_id := v_id;
  ELSE
    INSERT INTO expense.expense_report (reference, author, start_date, end_date, comment)
    VALUES (expense._next_reference(), v_author, v_start_date, v_end_date, v_comment) RETURNING id INTO v_report_id;
  END IF;
  RETURN pgv.toast(CASE WHEN v_id IS NOT NULL THEN pgv.t('expense.toast_note_updated') ELSE pgv.t('expense.toast_note_created') END)
    || pgv.redirect('/expense_report?p_id=' || v_report_id);
END;
$function$;
