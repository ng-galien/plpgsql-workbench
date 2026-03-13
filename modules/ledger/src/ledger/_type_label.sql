CREATE OR REPLACE FUNCTION ledger._type_label(p_type text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN CASE p_type
    WHEN 'asset'     THEN pgv.t('ledger.type_asset')
    WHEN 'liability' THEN pgv.t('ledger.type_liability')
    WHEN 'equity'    THEN pgv.t('ledger.type_equity')
    WHEN 'revenue'   THEN pgv.t('ledger.type_revenue')
    WHEN 'expense'   THEN pgv.t('ledger.type_expense')
    ELSE p_type
  END;
END;
$function$;
