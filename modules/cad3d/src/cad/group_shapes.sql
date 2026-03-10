CREATE OR REPLACE FUNCTION cad.group_shapes(p_drawing_id integer, p_shape_ids integer[], p_name text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_layer_id int;
  v_group_id int;
BEGIN
  -- Vérifier que tous les shapes existent et appartiennent au même dessin
  IF NOT EXISTS (
    SELECT 1 FROM cad.shape 
    WHERE id = ANY(p_shape_ids) AND drawing_id = p_drawing_id
    HAVING count(*) = array_length(p_shape_ids, 1)
  ) THEN
    RAISE EXCEPTION 'Certains shapes sont invalides ou n''appartiennent pas au dessin %', p_drawing_id;
  END IF;

  -- Prendre le layer du premier shape
  SELECT layer_id INTO v_layer_id FROM cad.shape WHERE id = p_shape_ids[1];

  -- Créer le shape group
  INSERT INTO cad.shape (drawing_id, layer_id, type, geometry, label)
  VALUES (p_drawing_id, v_layer_id, 'group', '{}', p_name)
  RETURNING id INTO v_group_id;

  -- Rattacher les shapes au group
  UPDATE cad.shape SET parent_id = v_group_id WHERE id = ANY(p_shape_ids);

  RETURN v_group_id;
END;
$function$;
