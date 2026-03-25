CREATE OR REPLACE FUNCTION expense._status_badge(p_status text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN pgv.badge(
    CASE p_status
      WHEN 'draft' THEN pgv.t('expense.status_draft')
      WHEN 'submitted' THEN pgv.t('expense.status_submitted')
      WHEN 'validated' THEN pgv.t('expense.status_validated')
      WHEN 'reimbursed' THEN pgv.t('expense.status_reimbursed')
      WHEN 'rejected' THEN pgv.t('expense.status_rejected')
      ELSE p_status
    END,
    CASE p_status
      WHEN 'draft' THEN 'secondary'
      WHEN 'submitted' THEN 'warning'
      WHEN 'validated' THEN 'info'
      WHEN 'reimbursed' THEN 'success'
      WHEN 'rejected' THEN 'danger'
      ELSE 'secondary'
    END
  );
END;
$function$;
