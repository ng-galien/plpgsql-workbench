CREATE OR REPLACE FUNCTION catalog.category_create(p_row catalog.category)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  p_row.sort_order := COALESCE(p_row.sort_order, 0);
  p_row.created_at := now();

  INSERT INTO catalog.category (name, parent_id, sort_order, created_at)
  VALUES (p_row.name, p_row.parent_id, p_row.sort_order, p_row.created_at)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
