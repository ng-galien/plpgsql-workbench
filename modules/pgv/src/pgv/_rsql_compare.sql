CREATE OR REPLACE FUNCTION pgv._rsql_compare(p_lhs text, p_op text, p_val text, p_numeric boolean, p_type text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  v_list_items text[];
  v_quoted_items text[];
  v_val text := p_val;
BEGIN
  CASE p_op
    WHEN '==' THEN
      IF p_numeric THEN
        RETURN p_lhs || ' = ' || v_val::numeric;
      ELSIF p_type = 'bool' THEN
        RETURN p_lhs || ' = ' || v_val::boolean;
      ELSE
        RETURN p_lhs || ' = ' || quote_literal(v_val);
      END IF;

    WHEN '!=' THEN
      IF p_numeric THEN
        RETURN p_lhs || ' != ' || v_val::numeric;
      ELSE
        RETURN p_lhs || ' != ' || quote_literal(v_val);
      END IF;

    WHEN '>', '>=', '<', '<=' THEN
      IF p_numeric THEN
        RETURN p_lhs || ' ' || p_op || ' ' || v_val::numeric;
      ELSE
        RETURN p_lhs || ' ' || p_op || ' ' || quote_literal(v_val);
      END IF;

    WHEN '=in=', '=out=' THEN
      v_val := trim(BOTH '()' FROM v_val);
      v_list_items := string_to_array(v_val, ',');
      v_quoted_items := '{}';
      FOR i IN 1..array_length(v_list_items, 1) LOOP
        IF p_numeric THEN
          v_quoted_items := v_quoted_items || (trim(v_list_items[i])::numeric)::text;
        ELSE
          v_quoted_items := v_quoted_items || quote_literal(trim(v_list_items[i]));
        END IF;
      END LOOP;
      IF p_op = '=in=' THEN
        RETURN p_lhs || ' IN (' || array_to_string(v_quoted_items, ', ') || ')';
      ELSE
        RETURN p_lhs || ' NOT IN (' || array_to_string(v_quoted_items, ', ') || ')';
      END IF;

    WHEN '=like=' THEN
      RETURN p_lhs || ' LIKE ' || quote_literal(replace(v_val, '*', '%'));

    WHEN '=ilike=' THEN
      RETURN p_lhs || ' ILIKE ' || quote_literal(replace(v_val, '*', '%'));

    WHEN '=isnull=' THEN
      IF lower(v_val) = 'true' THEN
        RETURN p_lhs || ' IS NULL';
      ELSE
        RETURN p_lhs || ' IS NOT NULL';
      END IF;

    WHEN '=notnull=' THEN
      IF lower(v_val) = 'true' THEN
        RETURN p_lhs || ' IS NOT NULL';
      ELSE
        RETURN p_lhs || ' IS NULL';
      END IF;

    WHEN '=bt=' THEN
      v_val := trim(BOTH '()' FROM v_val);
      v_list_items := string_to_array(v_val, ',');
      IF array_length(v_list_items, 1) != 2 THEN
        RAISE EXCEPTION 'rsql: =bt= requires exactly 2 values, got %', array_length(v_list_items, 1);
      END IF;
      IF p_numeric THEN
        RETURN p_lhs || ' BETWEEN ' || trim(v_list_items[1])::numeric || ' AND ' || trim(v_list_items[2])::numeric;
      ELSE
        RETURN p_lhs || ' BETWEEN ' || quote_literal(trim(v_list_items[1])) || ' AND ' || quote_literal(trim(v_list_items[2]));
      END IF;

    ELSE
      RAISE EXCEPTION 'rsql: unsupported operator "%"', p_op;
  END CASE;
END;
$function$;
