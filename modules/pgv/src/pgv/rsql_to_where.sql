CREATE OR REPLACE FUNCTION pgv.rsql_to_where(p_filter text, p_schema text, p_table text)
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
  v_col text;
  v_op text;
  v_val text;
  v_col_type text;
  v_sql_part text;
  v_match text[];
  v_list_items text[];
  v_quoted_items text[];
  v_is_numeric boolean;
BEGIN
  IF p_filter IS NULL OR trim(p_filter) = '' THEN
    RETURN 'true';
  END IF;

  -- Protect commas inside parentheses: replace with \x01
  v_val := p_filter;
  WHILE v_val ~ '\([^)]*,[^)]*\)' LOOP
    v_val := regexp_replace(v_val, '\(([^)]*),([^)]*)\)', '(\1' || chr(1) || '\2)', 'g');
  END LOOP;

  -- Split by , (OR)
  v_or_parts := string_to_array(v_val, ',');

  FOREACH v_or_part IN ARRAY v_or_parts LOOP
    v_and_clauses := '{}';
    -- Split by ; (AND)
    v_and_parts := string_to_array(v_or_part, ';');

    FOREACH v_and_part IN ARRAY v_and_parts LOOP
      -- Parse: column operator value
      v_match := regexp_match(v_and_part, '^([a-zA-Z_][a-zA-Z0-9_]*)(==|!=|>=|<=|>|<|=in=|=out=|=like=|=ilike=|=isnull=|=notnull=|=bt=)(.+)$');

      IF v_match IS NULL THEN
        RAISE EXCEPTION 'rsql: invalid expression "%"', v_and_part;
      END IF;

      v_col := v_match[1];
      v_op := v_match[2];
      v_val := replace(v_match[3], chr(1), ',');

      -- Validate column exists via pg_attribute + pg_type
      SELECT t.typname INTO v_col_type
      FROM pg_attribute a
      JOIN pg_class c ON c.oid = a.attrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN pg_type t ON t.oid = a.atttypid
      WHERE n.nspname = p_schema AND c.relname = p_table
        AND a.attname = v_col AND a.attnum > 0 AND NOT a.attisdropped;

      IF v_col_type IS NULL THEN
        RAISE EXCEPTION 'rsql: column "%" does not exist in %.%', v_col, p_schema, p_table;
      END IF;

      -- Determine if numeric type
      v_is_numeric := v_col_type IN ('int2', 'int4', 'int8', 'float4', 'float8', 'numeric');

      -- Build SQL fragment
      CASE v_op
        WHEN '==' THEN
          IF v_is_numeric THEN
            v_sql_part := format('%I = %s', v_col, v_val::numeric);
          ELSIF v_col_type = 'bool' THEN
            v_sql_part := format('%I = %s', v_col, v_val::boolean);
          ELSE
            v_sql_part := format('%I = %L', v_col, v_val);
          END IF;

        WHEN '!=' THEN
          IF v_is_numeric THEN
            v_sql_part := format('%I != %s', v_col, v_val::numeric);
          ELSE
            v_sql_part := format('%I != %L', v_col, v_val);
          END IF;

        WHEN '>', '>=', '<', '<=' THEN
          IF v_is_numeric THEN
            v_sql_part := format('%I %s %s', v_col, v_op, v_val::numeric);
          ELSE
            v_sql_part := format('%I %s %L', v_col, v_op, v_val);
          END IF;

        WHEN '=in=', '=out=' THEN
          v_val := trim(BOTH '()' FROM v_val);
          v_list_items := string_to_array(v_val, ',');
          v_quoted_items := '{}';
          FOR i IN 1..array_length(v_list_items, 1) LOOP
            IF v_is_numeric THEN
              v_quoted_items := v_quoted_items || (trim(v_list_items[i])::numeric)::text;
            ELSE
              v_quoted_items := v_quoted_items || quote_literal(trim(v_list_items[i]));
            END IF;
          END LOOP;
          IF v_op = '=in=' THEN
            v_sql_part := format('%I IN (%s)', v_col, array_to_string(v_quoted_items, ', '));
          ELSE
            v_sql_part := format('%I NOT IN (%s)', v_col, array_to_string(v_quoted_items, ', '));
          END IF;

        WHEN '=like=' THEN
          v_sql_part := format('%I LIKE %L', v_col, replace(v_val, '*', '%'));

        WHEN '=ilike=' THEN
          v_sql_part := format('%I ILIKE %L', v_col, replace(v_val, '*', '%'));

        WHEN '=isnull=' THEN
          IF lower(v_val) = 'true' THEN
            v_sql_part := format('%I IS NULL', v_col);
          ELSE
            v_sql_part := format('%I IS NOT NULL', v_col);
          END IF;

        WHEN '=notnull=' THEN
          IF lower(v_val) = 'true' THEN
            v_sql_part := format('%I IS NOT NULL', v_col);
          ELSE
            v_sql_part := format('%I IS NULL', v_col);
          END IF;

        WHEN '=bt=' THEN
          v_val := trim(BOTH '()' FROM v_val);
          v_list_items := string_to_array(v_val, ',');
          IF array_length(v_list_items, 1) != 2 THEN
            RAISE EXCEPTION 'rsql: =bt= requires exactly 2 values, got %', array_length(v_list_items, 1);
          END IF;
          IF v_is_numeric THEN
            v_sql_part := format('%I BETWEEN %s AND %s', v_col, trim(v_list_items[1])::numeric, trim(v_list_items[2])::numeric);
          ELSE
            v_sql_part := format('%I BETWEEN %L AND %L', v_col, trim(v_list_items[1]), trim(v_list_items[2]));
          END IF;

        ELSE
          RAISE EXCEPTION 'rsql: unsupported operator "%"', v_op;
      END CASE;

      v_and_clauses := v_and_clauses || v_sql_part;
    END LOOP;

    v_or_clauses := v_or_clauses || ('(' || array_to_string(v_and_clauses, ' AND ') || ')');
  END LOOP;

  IF array_length(v_or_clauses, 1) = 1 THEN
    -- Remove the single outer wrapping parens added for OR grouping
    RETURN substr(v_or_clauses[1], 2, length(v_or_clauses[1]) - 2);
  END IF;

  RETURN array_to_string(v_or_clauses, ' OR ');
END;
$function$;
