CREATE OR REPLACE FUNCTION document.group_remove_member(p_element_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE document.element
  SET parent_id = NULL
  WHERE id = p_element_id
    AND tenant_id = current_setting('app.tenant_id', true);
END;
$function$;
