CREATE OR REPLACE FUNCTION crm.post_import_csv(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_csv text;
  v_lines text[];
  v_cols text[];
  v_line text;
  v_imported int := 0;
  v_skipped int := 0;
  v_errors text := '';
  v_name text;
  v_type text;
  i int;
BEGIN
  v_csv := trim(COALESCE(p_data->>'csv', ''));
  IF v_csv = '' THEN
    RETURN '<template data-toast="error">Aucun contenu CSV fourni.</template>';
  END IF;

  v_lines := string_to_array(v_csv, E'\n');

  -- Skip header if it looks like one
  i := 1;
  IF lower(v_lines[1]) LIKE '%nom%' THEN
    i := 2;
  END IF;

  WHILE i <= array_length(v_lines, 1) LOOP
    v_line := trim(v_lines[i]);
    i := i + 1;

    IF v_line = '' THEN CONTINUE; END IF;

    -- Parse CSV line (simple split on ; or ,)
    IF position(';' IN v_line) > 0 THEN
      v_cols := string_to_array(v_line, ';');
    ELSE
      v_cols := string_to_array(v_line, ',');
    END IF;

    -- Columns: nom, email, telephone, adresse, ville, code_postal, type
    v_name := trim(COALESCE(v_cols[1], ''));
    IF v_name = '' THEN
      v_skipped := v_skipped + 1;
      v_errors := v_errors || 'Ligne ' || (i - 1) || ': nom vide. ';
      CONTINUE;
    END IF;

    v_type := lower(trim(COALESCE(v_cols[7], '')));
    IF v_type NOT IN ('individual', 'company') THEN
      v_type := 'individual';
    END IF;

    INSERT INTO crm.client (name, email, phone, address, city, postal_code, type)
    VALUES (
      v_name,
      NULLIF(trim(COALESCE(v_cols[2], '')), ''),
      NULLIF(trim(COALESCE(v_cols[3], '')), ''),
      NULLIF(trim(COALESCE(v_cols[4], '')), ''),
      NULLIF(trim(COALESCE(v_cols[5], '')), ''),
      NULLIF(trim(COALESCE(v_cols[6], '')), ''),
      v_type
    );
    v_imported := v_imported + 1;
  END LOOP;

  IF v_imported = 0 THEN
    RETURN '<template data-toast="error">Aucun client importé.' ||
      CASE WHEN v_skipped > 0 THEN ' ' || v_skipped || ' ligne(s) ignorée(s).' ELSE '' END ||
      '</template>';
  END IF;

  RETURN '<template data-toast="success">' || v_imported || ' client(s) importé(s).' ||
    CASE WHEN v_skipped > 0 THEN ' ' || v_skipped || ' ignoré(s).' ELSE '' END ||
    '</template>'
    || '<template data-redirect="' || pgv.call_ref('get_index') || '"></template>';
END;
$function$;
