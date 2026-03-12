CREATE OR REPLACE FUNCTION purchase._statut_badge(p_statut text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN CASE p_statut
    WHEN 'brouillon' THEN pgv.badge(p_statut, 'secondary')
    WHEN 'envoyee' THEN pgv.badge(p_statut, 'primary')
    WHEN 'partiellement_recue' THEN pgv.badge('partielle', 'warning')
    WHEN 'recue' THEN pgv.badge(p_statut, 'success')
    WHEN 'annulee' THEN pgv.badge(p_statut, 'error')
    WHEN 'validee' THEN pgv.badge(p_statut, 'success')
    WHEN 'payee' THEN pgv.badge(p_statut, 'success')
    ELSE pgv.badge(p_statut, 'secondary')
  END;
END;
$function$;
