CREATE OR REPLACE FUNCTION purchase._statut_badge(p_statut text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN CASE p_statut
    WHEN 'brouillon' THEN pgv.badge(pgv.t('purchase.status_brouillon'), 'default')
    WHEN 'envoyee' THEN pgv.badge(pgv.t('purchase.status_envoyee'), 'primary')
    WHEN 'partiellement_recue' THEN pgv.badge(pgv.t('purchase.status_partielle'), 'warning')
    WHEN 'recue' THEN pgv.badge(pgv.t('purchase.status_recue'), 'success')
    WHEN 'annulee' THEN pgv.badge(pgv.t('purchase.status_annulee'), 'danger')
    WHEN 'validee' THEN pgv.badge(pgv.t('purchase.status_validee'), 'success')
    WHEN 'payee' THEN pgv.badge(pgv.t('purchase.status_payee'), 'success')
    ELSE pgv.badge(p_statut, 'default')
  END;
END;
$function$;
