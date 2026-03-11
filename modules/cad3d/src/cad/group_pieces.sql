CREATE OR REPLACE FUNCTION cad.group_pieces(p_drawing_id integer, p_piece_ids integer[], p_label text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_group_id int;
BEGIN
  -- Valider que les pièces existent et appartiennent au dessin
  IF NOT EXISTS (
    SELECT 1 FROM cad.piece
    WHERE id = ANY(p_piece_ids) AND drawing_id = p_drawing_id
    HAVING count(*) = array_length(p_piece_ids, 1)
  ) THEN
    RAISE EXCEPTION 'Certaines pieces sont invalides ou n''appartiennent pas au dessin %', p_drawing_id;
  END IF;

  -- Créer le groupe
  INSERT INTO cad.piece_group (drawing_id, label)
  VALUES (p_drawing_id, p_label)
  RETURNING id INTO v_group_id;

  -- Rattacher les pièces au groupe
  UPDATE cad.piece SET group_id = v_group_id WHERE id = ANY(p_piece_ids);

  RETURN v_group_id;
END;
$function$;
