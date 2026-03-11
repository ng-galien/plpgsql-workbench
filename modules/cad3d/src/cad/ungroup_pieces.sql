CREATE OR REPLACE FUNCTION cad.ungroup_pieces(p_group_id integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_count int;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cad.piece_group WHERE id = p_group_id) THEN
    RAISE EXCEPTION 'Groupe #% introuvable', p_group_id;
  END IF;

  -- Détacher les pièces
  UPDATE cad.piece SET group_id = NULL WHERE group_id = p_group_id;
  GET DIAGNOSTICS v_count = ROW_COUNT;

  -- Détacher les sous-groupes (deviennent racine)
  UPDATE cad.piece_group SET parent_id = NULL WHERE parent_id = p_group_id;

  -- Supprimer le groupe
  DELETE FROM cad.piece_group WHERE id = p_group_id;

  RETURN v_count;
END;
$function$;
