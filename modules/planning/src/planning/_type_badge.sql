CREATE OR REPLACE FUNCTION planning._type_badge(p_type text)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT pgv.badge(
    CASE p_type
      WHEN 'chantier'  THEN pgv.t('planning.type_chantier')
      WHEN 'livraison' THEN pgv.t('planning.type_livraison')
      WHEN 'reunion'   THEN pgv.t('planning.type_reunion')
      WHEN 'conge'     THEN pgv.t('planning.type_conge')
      ELSE pgv.t('planning.type_autre')
    END,
    CASE p_type
      WHEN 'chantier'  THEN 'info'
      WHEN 'livraison' THEN 'warning'
      WHEN 'reunion'   THEN 'default'
      WHEN 'conge'     THEN 'error'
      ELSE 'default'
    END
  );
$function$;
