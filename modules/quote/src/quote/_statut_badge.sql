CREATE OR REPLACE FUNCTION quote._statut_badge(p_statut text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN pgv.badge(
    CASE p_statut
      WHEN 'brouillon' THEN 'Brouillon'
      WHEN 'envoye'    THEN 'Envoyé'
      WHEN 'envoyee'   THEN 'Envoyée'
      WHEN 'accepte'   THEN 'Accepté'
      WHEN 'payee'     THEN 'Payée'
      WHEN 'refuse'    THEN 'Refusé'
      ELSE initcap(p_statut)
    END,
    CASE p_statut
      WHEN 'brouillon' THEN 'warning'
      WHEN 'envoye'    THEN 'info'
      WHEN 'envoyee'   THEN 'info'
      WHEN 'accepte'   THEN 'success'
      WHEN 'payee'     THEN 'success'
      WHEN 'refuse'    THEN 'danger'
    END
  );
END;
$function$;
