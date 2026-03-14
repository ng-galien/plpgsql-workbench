CREATE OR REPLACE FUNCTION document.group_dissolve(p_group_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_parent uuid;
  v_count int;
BEGIN
  -- Get parent of the group
  SELECT parent_id INTO v_parent
  FROM document.element
  WHERE id = p_group_id AND type = 'group'
    AND tenant_id = current_setting('app.tenant_id', true);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Group not found: %', p_group_id;
  END IF;

  -- Reparent children to the group's parent
  UPDATE document.element
  SET parent_id = v_parent
  WHERE parent_id = p_group_id;
  GET DIAGNOSTICS v_count = ROW_COUNT;

  -- Delete the group element
  DELETE FROM document.element WHERE id = p_group_id;

  RETURN v_count;
END;
$function$;
