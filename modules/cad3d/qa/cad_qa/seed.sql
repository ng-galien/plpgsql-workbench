CREATE OR REPLACE FUNCTION cad_qa.seed()
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_did int;
BEGIN
  -- Nettoyer les anciens seeds
  DELETE FROM cad.drawing WHERE name = 'QA — Abri bois';

  -- Créer un dessin de démo
  INSERT INTO cad.drawing (name, width, height, scale)
  VALUES ('QA — Abri bois', 3000, 2500, 1)
  RETURNING id INTO v_did;

  INSERT INTO cad.layer (drawing_id, name, color, stroke_width)
  VALUES (v_did, 'Structure', '#333333', 1.5);

  -- 4 poteaux (coins)
  PERFORM cad.add_piece(v_did, '90x90', 2400, ARRAY[0,0,0],       ARRAY[0,0,0], 'Poteau AV-G', 'poteau');
  PERFORM cad.add_piece(v_did, '90x90', 2400, ARRAY[2000,0,0],    ARRAY[0,0,0], 'Poteau AV-D', 'poteau');
  PERFORM cad.add_piece(v_did, '90x90', 2400, ARRAY[0,2000,0],    ARRAY[0,0,0], 'Poteau AR-G', 'poteau');
  PERFORM cad.add_piece(v_did, '90x90', 2400, ARRAY[2000,2000,0], ARRAY[0,0,0], 'Poteau AR-D', 'poteau');

  -- 4 traverses hautes (liant les poteaux)
  PERFORM cad.add_piece(v_did, '45x90', 2000, ARRAY[0,0,2400],    ARRAY[0,90,0],  'Traverse AV',  'traverse');
  PERFORM cad.add_piece(v_did, '45x90', 2000, ARRAY[0,2000,2400], ARRAY[0,90,0],  'Traverse AR',  'traverse');
  PERFORM cad.add_piece(v_did, '45x90', 2000, ARRAY[0,0,2400],    ARRAY[90,0,0],  'Traverse G',   'traverse');
  PERFORM cad.add_piece(v_did, '45x90', 2000, ARRAY[2000,0,2400], ARRAY[90,0,0],  'Traverse D',   'traverse');

  -- 3 chevrons (toiture)
  PERFORM cad.add_piece(v_did, '45x120', 2200, ARRAY[200,0,2490],  ARRAY[90,0,0], 'Chevron 1', 'chevron');
  PERFORM cad.add_piece(v_did, '45x120', 2200, ARRAY[1000,0,2490], ARRAY[90,0,0], 'Chevron 2', 'chevron');
  PERFORM cad.add_piece(v_did, '45x120', 2200, ARRAY[1800,0,2490], ARRAY[90,0,0], 'Chevron 3', 'chevron');

  RETURN '<template data-toast="success">Seed QA créé: abri bois (' || v_did || ')</template>'
    || '<template data-redirect="/"></template>';
END;
$function$;
