CREATE OR REPLACE FUNCTION cad.ungroup(p_group_id integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_count int;
BEGIN
  -- Vérifier que c'est bien un group
  IF NOT EXISTS (SELECT 1 FROM cad.shape WHERE id = p_group_id AND type = 'group') THEN
    RAISE EXCEPTION 'Shape % n''est pas un groupe', p_group_id;
  END IF;

  -- Détacher les enfants
  UPDATE cad.shape SET parent_id = NULL WHERE parent_id = p_group_id;
  GET DIAGNOSTICS v_count = ROW_COUNT;

  -- Supprimer le group
  DELETE FROM cad.shape WHERE id = p_group_id;

  RETURN v_count;
END;
$function$;
