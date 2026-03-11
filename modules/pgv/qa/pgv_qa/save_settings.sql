CREATE OR REPLACE FUNCTION pgv_qa.save_settings(p_documentsroot text DEFAULT NULL::text)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF p_documentsroot IS NOT NULL AND p_documentsroot <> '' THEN
    INSERT INTO pgv_qa.setting (key, value, updated_at)
    VALUES ('documentsRoot', p_documentsroot, now())
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();
  END IF;
  RETURN '<template data-toast="success">Configuration enregistree</template>'
      || '<template data-redirect="/settings"></template>';
END;
$function$;
