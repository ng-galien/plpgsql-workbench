CREATE OR REPLACE FUNCTION cad.move_group_pieces(p_group_id integer, p_dx real DEFAULT 0, p_dy real DEFAULT 0, p_dz real DEFAULT 0)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_label text;
  v_count int;
  v_child_id int;
  v_total int := 0;
BEGIN
  SELECT label INTO v_label FROM cad.piece_group WHERE id = p_group_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Groupe #% introuvable', p_group_id;
  END IF;

  -- Translater les pièces directes du groupe
  UPDATE cad.piece SET
    geom = ST_Translate(geom, p_dx, p_dy, p_dz),
    profile = ST_Translate(profile, p_dx, p_dy, p_dz)
  WHERE group_id = p_group_id;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  v_total := v_count;

  -- Récursif sur les sous-groupes
  FOR v_child_id IN
    SELECT id FROM cad.piece_group WHERE parent_id = p_group_id
  LOOP
    PERFORM cad.move_group_pieces(v_child_id, p_dx, p_dy, p_dz);
    v_total := v_total + (SELECT count(*)::int FROM cad.piece WHERE group_id = v_child_id);
  END LOOP;

  RETURN format('moved %s pieces in group "%s" by [%s, %s, %s]', v_total, v_label, p_dx, p_dy, p_dz);
END;
$function$;
