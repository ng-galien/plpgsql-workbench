CREATE OR REPLACE FUNCTION catalog.category_update(p_row catalog.category)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE catalog.category SET
    name = COALESCE(p_row.name, name),
    parent_id = COALESCE(p_row.parent_id, parent_id),
    sort_order = COALESCE(p_row.sort_order, sort_order)
  WHERE id = p_row.id
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
