CREATE OR REPLACE FUNCTION quote._statut_badge(p_statut text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN pgv.badge(
    CASE p_statut
      WHEN 'brouillon' THEN pgv.t('quote.status_brouillon')
      WHEN 'envoye'    THEN pgv.t('quote.status_envoye')
      WHEN 'envoyee'   THEN pgv.t('quote.status_envoyee')
      WHEN 'accepte'   THEN pgv.t('quote.status_accepte')
      WHEN 'payee'     THEN pgv.t('quote.status_payee')
      WHEN 'refuse'    THEN pgv.t('quote.status_refuse')
      WHEN 'relance'   THEN pgv.t('quote.status_relance')
      ELSE initcap(p_statut)
    END,
    CASE p_statut
      WHEN 'brouillon' THEN 'warning'
      WHEN 'envoye'    THEN 'info'
      WHEN 'envoyee'   THEN 'info'
      WHEN 'accepte'   THEN 'success'
      WHEN 'payee'     THEN 'success'
      WHEN 'refuse'    THEN 'danger'
      WHEN 'relance'   THEN 'danger'
    END
  );
END;
$function$;
