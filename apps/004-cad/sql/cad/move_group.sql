CREATE OR REPLACE FUNCTION cad.move_group(p_group_id integer, p_dx real, p_dy real)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_count int;
  v_child record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cad.shape WHERE id = p_group_id AND type = 'group') THEN
    RAISE EXCEPTION 'Shape % n''est pas un groupe', p_group_id;
  END IF;

  v_count := 0;
  FOR v_child IN
    SELECT id, type, geometry FROM cad.shape WHERE parent_id = p_group_id
  LOOP
    IF v_child.type = 'group' THEN
      -- Récursif pour les sous-groupes
      PERFORM cad.move_group(v_child.id, p_dx, p_dy);
    ELSE
      PERFORM cad.move_shape(v_child.id, p_dx, p_dy);
    END IF;
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$function$;
