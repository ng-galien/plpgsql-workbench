CREATE OR REPLACE FUNCTION cad.page(p_path text, p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_parts text[];
  v_nav jsonb := '[{"href":"/","label":"Dessins"}]';
  v_brand text := 'CAD 3D';
  v_id int;
BEGIN
  v_parts := string_to_array(trim(BOTH '/' FROM p_path), '/');

  -- GET /
  IF p_path = '/' OR p_path IS NULL THEN
    RETURN pgv.page(v_brand, 'Dessins', '/', v_nav, cad.page_index());
  END IF;

  -- POST /drawing/add
  IF v_parts = ARRAY['drawing','add'] THEN
    RETURN cad.page_drawing_add(p_body);
  END IF;

  -- GET /drawing/:id
  IF array_length(v_parts,1) = 2 AND v_parts[1] = 'drawing' THEN
    v_id := v_parts[2]::int;
    RETURN pgv.page(v_brand, (SELECT name FROM cad.drawing WHERE id = v_id),
      p_path, v_nav, cad.page_drawing(v_id));
  END IF;

  -- GET /drawing/:id/3d
  IF array_length(v_parts,1) = 3 AND v_parts[1] = 'drawing' AND v_parts[3] = '3d' THEN
    v_id := v_parts[2]::int;
    RETURN pgv.page(v_brand, 'Vue 3D',
      p_path, v_nav, cad.page_drawing_3d(v_id));
  END IF;

  -- GET /drawing/:id/bom
  IF array_length(v_parts,1) = 3 AND v_parts[1] = 'drawing' AND v_parts[3] = 'bom' THEN
    v_id := v_parts[2]::int;
    RETURN pgv.page(v_brand, 'Liste de débit',
      p_path, v_nav, cad.page_drawing_bom(v_id));
  END IF;

  -- POST /drawing/:id/add-shape
  IF array_length(v_parts,1) = 3 AND v_parts[1] = 'drawing' AND v_parts[3] = 'add-shape' THEN
    v_id := v_parts[2]::int;
    RETURN cad.page_drawing_add_shape(v_id, p_body);
  END IF;

  -- POST /drawing/:id/delete-shape
  IF array_length(v_parts,1) = 3 AND v_parts[1] = 'drawing' AND v_parts[3] = 'delete-shape' THEN
    v_id := v_parts[2]::int;
    RETURN cad.page_drawing_delete_shape(v_id, p_body);
  END IF;

  -- 404
  RETURN pgv.page(v_brand, '404', p_path, v_nav,
    pgv.error('404', 'Page non trouvée', 'Le chemin ' || p_path || ' n''existe pas.'));
END;
$function$;
