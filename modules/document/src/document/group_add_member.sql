CREATE OR REPLACE FUNCTION document.group_add_member(p_group_id uuid, p_element_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE document.element
  SET parent_id = p_group_id
  WHERE id = p_element_id
    AND tenant_id = current_setting('app.tenant_id', true);
END;
$function$;
