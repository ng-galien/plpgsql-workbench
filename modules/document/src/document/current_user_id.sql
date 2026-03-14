CREATE OR REPLACE FUNCTION document.current_user_id()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT CASE
    WHEN NULLIF(current_setting('app.user_id', true), '') IS NOT NULL
      THEN current_setting('app.user_id', true)
    ELSE 'dev'
  END;
$function$;
