CREATE OR REPLACE FUNCTION quote._status_badge(p_status text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN pgv.badge(pgv.t('quote.status_' || p_status),
    CASE p_status
      WHEN 'draft' THEN 'warning'
      WHEN 'sent' THEN 'info'
      WHEN 'accepted' THEN 'success'
      WHEN 'declined' THEN 'error'
      WHEN 'paid' THEN 'success'
      WHEN 'overdue' THEN 'danger'
      ELSE 'muted'
    END
  );
END;
$function$;
