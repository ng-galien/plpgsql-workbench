CREATE OR REPLACE FUNCTION document.element_batch_update(p_updates jsonb)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_item jsonb;
  v_count int := 0;
BEGIN
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_updates)
  LOOP
    PERFORM document.element_update(
      (v_item->>'id')::uuid,
      v_item - 'id'
    );
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$function$;
