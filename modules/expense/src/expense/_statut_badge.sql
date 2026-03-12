CREATE OR REPLACE FUNCTION expense._statut_badge(p_statut text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN pgv.badge(
    CASE p_statut
      WHEN 'brouillon'   THEN 'Brouillon'
      WHEN 'soumise'     THEN 'Soumise'
      WHEN 'validee'     THEN 'Validée'
      WHEN 'remboursee'  THEN 'Remboursée'
      WHEN 'rejetee'     THEN 'Rejetée'
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
