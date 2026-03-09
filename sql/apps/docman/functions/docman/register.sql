CREATE OR REPLACE FUNCTION docman.register(p_dir text DEFAULT NULL::text, p_source text DEFAULT 'filesystem'::text)
 RETURNS TABLE(registered integer, skipped integer)
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_registered INT := 0;
  v_file RECORD;
BEGIN
  FOR v_file IN
    SELECT f.path
    FROM docstore.file f
    WHERE (p_dir IS NULL OR f.path LIKE p_dir || '%')
      AND NOT EXISTS (
        SELECT 1 FROM docman.document d WHERE d.file_path = f.path
      )
  LOOP
    INSERT INTO docman.document (file_path, source)
    VALUES (v_file.path, p_source);
    v_registered := v_registered + 1;
  END LOOP;

  skipped := (
    SELECT count(*)::INT FROM docstore.file f
    WHERE (p_dir IS NULL OR f.path LIKE p_dir || '%')
  ) - v_registered;

  RETURN QUERY SELECT v_registered, skipped;
END;
$function$;
