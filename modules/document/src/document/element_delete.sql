CREATE OR REPLACE FUNCTION document.element_delete(p_element_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_info jsonb;
BEGIN
  SELECT jsonb_build_object('id', id, 'name', name, 'type', type) INTO v_info
  FROM document.element
  WHERE id = p_element_id
    AND tenant_id = current_setting('app.tenant_id', true);

  IF v_info IS NULL THEN
    RETURN NULL;
  END IF;

  -- CASCADE deletes children via FK
  DELETE FROM document.element WHERE id = p_element_id;

  RETURN v_info;
END;
$function$;
