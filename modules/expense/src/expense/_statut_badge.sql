CREATE OR REPLACE FUNCTION expense._statut_badge(p_statut text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN pgv.badge(
    CASE p_statut
      WHEN 'brouillon'   THEN pgv.t('expense.statut_brouillon')
      WHEN 'soumise'     THEN pgv.t('expense.statut_soumise')
      WHEN 'validee'     THEN pgv.t('expense.statut_validee')
      WHEN 'remboursee'  THEN pgv.t('expense.statut_remboursee')
      WHEN 'rejetee'     THEN pgv.t('expense.statut_rejetee')
      ELSE initcap(p_statut)
    END,
    CASE p_statut
      WHEN 'brouillon'   THEN 'warning'
      WHEN 'soumise'     THEN 'info'
      WHEN 'validee'     THEN 'success'
      WHEN 'remboursee'  THEN 'success'
      WHEN 'rejetee'     THEN 'danger'
    END
  );
END;
$function$;
