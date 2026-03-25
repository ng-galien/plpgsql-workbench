CREATE OR REPLACE FUNCTION purchase._status_badge(p_status text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN CASE p_status
    WHEN 'draft' THEN pgv.badge(pgv.t('purchase.status_draft'), 'default')
    WHEN 'sent' THEN pgv.badge(pgv.t('purchase.status_sent'), 'primary')
    WHEN 'partially_received' THEN pgv.badge(pgv.t('purchase.status_partially_received'), 'warning')
    WHEN 'received' THEN pgv.badge(pgv.t('purchase.status_received'), 'success')
    WHEN 'cancelled' THEN pgv.badge(pgv.t('purchase.status_cancelled'), 'danger')
    WHEN 'validated' THEN pgv.badge(pgv.t('purchase.status_validated'), 'primary')
    WHEN 'paid' THEN pgv.badge(pgv.t('purchase.status_paid'), 'success')
    ELSE pgv.badge(p_status, 'default')
  END;
END;
$function$;
