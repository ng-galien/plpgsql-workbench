CREATE OR REPLACE FUNCTION cad.drawing_add(name text)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
BEGIN
  IF name IS NULL OR trim(name) = '' THEN
    RETURN '<template data-toast="error">Nom requis</template>';
  END IF;

  INSERT INTO cad.drawing (name) VALUES (trim(name)) RETURNING id INTO v_id;

  -- Créer un calque par défaut
  INSERT INTO cad.layer (drawing_id, name, color, stroke_width)
  VALUES (v_id, 'Structure', '#333333', 1.5);

  RETURN format('<template data-redirect="/drawing/%s"></template>', v_id);
END;
$function$;
