CREATE OR REPLACE FUNCTION project._statut_badge(p_statut text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  RETURN pgv.badge(
    CASE p_statut
      WHEN 'preparation' THEN 'Préparation'
      WHEN 'execution'   THEN 'En cours'
      WHEN 'reception'   THEN 'Réception'
      WHEN 'clos'        THEN 'Clos'
      ELSE initcap(p_statut)
    END,
    CASE p_statut
      WHEN 'preparation' THEN 'warning'
      WHEN 'execution'   THEN 'info'
      WHEN 'reception'   THEN 'success'
      WHEN 'clos'        THEN 'default'
    END
  );
END;
$function$;
