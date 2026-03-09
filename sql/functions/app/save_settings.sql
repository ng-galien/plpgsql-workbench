CREATE OR REPLACE FUNCTION app.save_settings(p_documentsroot text DEFAULT NULL::text)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF p_documentsroot IS NOT NULL AND p_documentsroot <> '' THEN
    INSERT INTO workbench.config (app, key, value)
    VALUES ('docman', 'documentsRoot', p_documentsroot)
    ON CONFLICT (app, key) DO UPDATE SET value = EXCLUDED.value;
  END IF;

  -- Redirect back to settings page
  PERFORM set_config('response.headers',
    '[{"HX-Redirect": "/settings"}]', true);
  RETURN '';
END;
$function$;
