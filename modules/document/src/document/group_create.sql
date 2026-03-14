CREATE OR REPLACE FUNCTION document.group_create(p_canvas_id uuid, p_element_ids uuid[], p_name text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_parent uuid;
  v_group_id uuid;
  v_max_order int;
BEGIN
  -- Verify all elements are siblings (same parent_id)
  SELECT DISTINCT parent_id INTO STRICT v_parent
  FROM document.element
  WHERE id = ANY(p_element_ids) AND canvas_id = p_canvas_id;

  -- Get max sort_order for positioning
  SELECT COALESCE(max(sort_order), 0) INTO v_max_order
  FROM document.element WHERE canvas_id = p_canvas_id;

  -- Create group element with same parent
  INSERT INTO document.element (canvas_id, type, parent_id, sort_order, name)
  VALUES (p_canvas_id, 'group', v_parent, v_max_order + 1, p_name)
  RETURNING id INTO v_group_id;

  -- Reparent elements into the group
  UPDATE document.element
  SET parent_id = v_group_id
  WHERE id = ANY(p_element_ids) AND canvas_id = p_canvas_id;

  RETURN v_group_id;

EXCEPTION WHEN too_many_rows THEN
  RAISE EXCEPTION 'Cannot group elements with different parents';
END;
$function$;
