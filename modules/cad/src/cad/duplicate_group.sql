CREATE OR REPLACE FUNCTION cad.duplicate_group(p_group_id integer, p_dx real DEFAULT 0, p_dy real DEFAULT 0, p_dz real DEFAULT 0, p_label text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_src cad.piece_group;
  v_new_group_id int;
  v_piece record;
  v_child_id int;
BEGIN
  SELECT * INTO v_src FROM cad.piece_group WHERE id = p_group_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Groupe #% introuvable', p_group_id;
  END IF;

  -- Créer le nouveau groupe
  INSERT INTO cad.piece_group (drawing_id, parent_id, label)
  VALUES (v_src.drawing_id, v_src.parent_id, coalesce(p_label, v_src.label || ' (copy)'))
  RETURNING id INTO v_new_group_id;

  -- Dupliquer les pièces directes avec offset
  FOR v_piece IN
    SELECT * FROM cad.piece WHERE group_id = p_group_id
  LOOP
    INSERT INTO cad.piece (drawing_id, label, role, wood_type, section, length_mm, profile, geom, group_id)
    VALUES (
      v_piece.drawing_id,
      v_piece.label,
      v_piece.role,
      v_piece.wood_type,
      v_piece.section,
      v_piece.length_mm,
      ST_Translate(v_piece.profile, p_dx, p_dy, p_dz),
      ST_Translate(v_piece.geom, p_dx, p_dy, p_dz),
      v_new_group_id
    );
  END LOOP;

  -- Récursif sur les sous-groupes
  FOR v_child_id IN
    SELECT id FROM cad.piece_group WHERE parent_id = p_group_id
  LOOP
    -- Dupliquer le sous-groupe, re-parenter vers le nouveau groupe
    DECLARE
      v_sub_id int;
    BEGIN
      v_sub_id := cad.duplicate_group(v_child_id, p_dx, p_dy, p_dz);
      UPDATE cad.piece_group SET parent_id = v_new_group_id WHERE id = v_sub_id;
    END;
  END LOOP;

  RETURN v_new_group_id;
END;
$function$;
