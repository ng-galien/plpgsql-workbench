CREATE OR REPLACE FUNCTION cad.remove_group(p_group_id integer, p_keep_pieces boolean DEFAULT false)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_label text;
  v_count int := 0;
  v_child_id int;
BEGIN
  SELECT label INTO v_label FROM cad.piece_group WHERE id = p_group_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Groupe #% introuvable', p_group_id;
  END IF;

  -- Récursif sur les sous-groupes d'abord
  FOR v_child_id IN
    SELECT id FROM cad.piece_group WHERE parent_id = p_group_id
  LOOP
    PERFORM cad.remove_group(v_child_id, p_keep_pieces);
  END LOOP;

  IF p_keep_pieces THEN
    UPDATE cad.piece SET group_id = NULL WHERE group_id = p_group_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
  ELSE
    DELETE FROM cad.piece WHERE group_id = p_group_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
  END IF;

  DELETE FROM cad.piece_group WHERE id = p_group_id;

  IF p_keep_pieces THEN
    RETURN format('dissolved group "%s" (%s pieces detached)', v_label, v_count);
  ELSE
    RETURN format('removed group "%s" (%s pieces deleted)', v_label, v_count);
  END IF;
END;
$function$;
