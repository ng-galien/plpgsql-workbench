CREATE OR REPLACE FUNCTION expense.post_line_add(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_note_id int := (p_params->>'note_id')::int;
  v_date date := (p_params->>'expense_date')::date;
  v_category_id int := (p_params->>'category_id')::int;
  v_description text := p_params->>'description';
  v_amount numeric(12,2) := (p_params->>'amount_excl_tax')::numeric;
  v_vat numeric(12,2) := coalesce((p_params->>'vat')::numeric, 0);
  v_km numeric(8,1) := (p_params->>'km')::numeric;
  v_status text;
BEGIN
  IF v_note_id IS NULL OR v_date IS NULL OR v_description IS NULL OR v_amount IS NULL THEN
    RETURN pgv.toast(pgv.t('expense.err_line_fields'), 'error');
  END IF;
  SELECT status INTO v_status FROM expense.expense_report WHERE id = v_note_id;
  IF NOT FOUND THEN RETURN pgv.toast(pgv.t('expense.err_note_not_found'), 'error'); END IF;
  IF v_status <> 'draft' THEN RETURN pgv.toast(pgv.t('expense.err_not_draft'), 'error'); END IF;
  INSERT INTO expense.line (note_id, expense_date, category_id, description, amount_excl_tax, vat, km)
  VALUES (v_note_id, v_date, v_category_id, v_description, v_amount, v_vat, v_km);
  RETURN pgv.toast(pgv.t('expense.toast_line_added')) || pgv.redirect('/expense_report?p_id=' || v_note_id);
END;
$function$;
