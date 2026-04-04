CREATE OR REPLACE FUNCTION query.rsql_to_where(p_filter text, p_schema text, p_table text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_or_parts text[];
  v_or_part text;
  v_and_parts text[];
  v_and_part text;
  v_or_clauses text[] := '{}';
  v_and_clauses text[];
  v_field text;
  v_op text;
  v_val text;
  v_col text;
  v_col_type text;
  v_sql_part text;
  v_match text[];
  v_is_numeric boolean;
  v_path text[];
  v_jsonb_path text;
  v_fk_target_schema text;
  v_fk_target_table text;
  v_fk_src_col text;
  v_fk_tgt_col text;
  v_fk_filter_col text;
  v_fk_col_type text;
BEGIN
  IF p_filter IS NULL OR trim(p_filter) = '' THEN
    RETURN 'true';
  END IF;

  v_val := p_filter;
  WHILE v_val ~ '\([^)]*,[^)]*\)' LOOP
    v_val := regexp_replace(v_val, '\(([^)]*),([^)]*)\)', '(\1' || chr(1) || '\2)', 'g');
  END LOOP;

  v_or_parts := string_to_array(v_val, ',');

  FOREACH v_or_part IN ARRAY v_or_parts LOOP
    v_and_clauses := '{}';
    v_and_parts := string_to_array(v_or_part, ';');

    FOREACH v_and_part IN ARRAY v_and_parts LOOP
      v_match := regexp_match(v_and_part, '^([a-zA-Z_][a-zA-Z0-9_.]*)(==|!=|>=|<=|>|<|=in=|=out=|=like=|=ilike=|=isnull=|=notnull=|=bt=)(.+)$');

      IF v_match IS NULL THEN
        RAISE EXCEPTION 'rsql: invalid expression "%"', v_and_part;
      END IF;

      v_field := v_match[1];
      v_op := v_match[2];
      v_val := replace(v_match[3], chr(1), ',');

      v_path := string_to_array(v_field, '.');
      v_col := v_path[1];

      -- Look up column type
      SELECT t.typname INTO v_col_type
      FROM pg_attribute a
      JOIN pg_class c ON c.oid = a.attrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN pg_type t ON t.oid = a.atttypid
      WHERE n.nspname = p_schema AND c.relname = p_table
        AND a.attname = v_col AND a.attnum > 0 AND NOT a.attisdropped;

      -- v3: FK relation traversal (first segment = related table name)
      IF v_col_type IS NULL AND array_length(v_path, 1) > 1 THEN
        SELECT n2.nspname, c2.relname, a1.attname, a2.attname
        INTO v_fk_target_schema, v_fk_target_table, v_fk_src_col, v_fk_tgt_col
        FROM pg_constraint con
        JOIN pg_class c1 ON c1.oid = con.conrelid
        JOIN pg_namespace n1 ON n1.oid = c1.relnamespace
        JOIN pg_class c2 ON c2.oid = con.confrelid
        JOIN pg_namespace n2 ON n2.oid = c2.relnamespace
        JOIN pg_attribute a1 ON a1.attrelid = con.conrelid AND a1.attnum = con.conkey[1]
        JOIN pg_attribute a2 ON a2.attrelid = con.confrelid AND a2.attnum = con.confkey[1]
        WHERE con.contype = 'f'
          AND n1.nspname = p_schema AND c1.relname = p_table
          AND c2.relname = v_col;

        IF v_fk_target_schema IS NULL THEN
          RAISE EXCEPTION 'rsql: "%" is not a column or FK relation in %.%', v_col, p_schema, p_table;
        END IF;

        v_fk_filter_col := v_path[2];
        SELECT t.typname INTO v_fk_col_type
        FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        JOIN pg_type t ON t.oid = a.atttypid
        WHERE n.nspname = v_fk_target_schema AND c.relname = v_fk_target_table
          AND a.attname = v_fk_filter_col AND a.attnum > 0 AND NOT a.attisdropped;

        IF v_fk_col_type IS NULL THEN
          RAISE EXCEPTION 'rsql: column "%" does not exist in %.%', v_fk_filter_col, v_fk_target_schema, v_fk_target_table;
        END IF;

        v_is_numeric := v_fk_col_type IN ('int2', 'int4', 'int8', 'float4', 'float8', 'numeric');
        v_sql_part := query._rsql_compare(format('%I', v_fk_filter_col), v_op, v_val, v_is_numeric, v_fk_col_type);
        v_sql_part := format('EXISTS (SELECT 1 FROM %I.%I WHERE %I = %I.%I AND %s)',
          v_fk_target_schema, v_fk_target_table,
          v_fk_tgt_col, p_table, v_fk_src_col, v_sql_part);

        v_and_clauses := v_and_clauses || v_sql_part;
        CONTINUE;
      END IF;

      IF v_col_type IS NULL THEN
        RAISE EXCEPTION 'rsql: column "%" does not exist in %.%', v_col, p_schema, p_table;
      END IF;

      -- v2: JSONB traversal
      IF array_length(v_path, 1) > 1 AND v_col_type = 'jsonb' THEN
        v_jsonb_path := format('%I', v_col);
        FOR i IN 2..array_length(v_path, 1) LOOP
          IF i = array_length(v_path, 1) THEN
            IF v_path[i] ~ '^\d+$' THEN
              v_jsonb_path := v_jsonb_path || '->>' || v_path[i];
            ELSE
              v_jsonb_path := v_jsonb_path || '->>''' || v_path[i] || '''';
            END IF;
          ELSE
            IF v_path[i] ~ '^\d+$' THEN
              v_jsonb_path := v_jsonb_path || '->' || v_path[i];
            ELSE
              v_jsonb_path := v_jsonb_path || '->''' || v_path[i] || '''';
            END IF;
          END IF;
        END LOOP;

        v_sql_part := query._rsql_compare(v_jsonb_path, v_op, v_val, false, 'text');
        v_and_clauses := v_and_clauses || v_sql_part;
        CONTINUE;
      END IF;

      -- Simple column
      v_is_numeric := v_col_type IN ('int2', 'int4', 'int8', 'float4', 'float8', 'numeric');
      v_sql_part := query._rsql_compare(format('%I', v_col), v_op, v_val, v_is_numeric, v_col_type);
      v_and_clauses := v_and_clauses || v_sql_part;
    END LOOP;

    v_or_clauses := v_or_clauses || ('(' || array_to_string(v_and_clauses, ' AND ') || ')');
  END LOOP;

  IF array_length(v_or_clauses, 1) = 1 THEN
    RETURN substr(v_or_clauses[1], 2, length(v_or_clauses[1]) - 2);
  END IF;

  RETURN array_to_string(v_or_clauses, ' OR ');
END;
$function$;
