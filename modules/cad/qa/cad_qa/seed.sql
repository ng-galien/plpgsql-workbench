CREATE OR REPLACE FUNCTION cad_qa.seed()
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_did int;
  v_pav_g int; v_pav_d int; v_par_g int; v_par_d int;
  v_tav int; v_tar int; v_tg int; v_td int;
  v_c1 int; v_c2 int; v_c3 int; v_c4 int; v_c5 int;
  v_lav int; v_lar int; v_lg int; v_ld int;
  v_g_ossature int; v_g_toiture int; v_g_lisses int;
  v_g_face_av int; v_g_face_ar int;
BEGIN
  -- Set tenant context for RLS
  PERFORM set_config('app.tenant_id', 'dev', true);

  DELETE FROM cad.drawing WHERE name = 'QA — Abri bois';

  INSERT INTO cad.drawing (name, width, height, scale)
  VALUES ('QA — Abri bois', 3000, 2500, 1)
  RETURNING id INTO v_did;

  INSERT INTO cad.layer (drawing_id, name, color, stroke_width)
  VALUES (v_did, 'Structure', '#333333', 1.5);

  -- === POTEAUX (4 coins, vertical, 90x90mm, 2400mm) ===
  v_pav_g := cad.add_piece(v_did, '90x90', 2400, ARRAY[0,0,0],       ARRAY[0,0,0], 'Poteau AV-G', 'poteau');
  v_pav_d := cad.add_piece(v_did, '90x90', 2400, ARRAY[2000,0,0],    ARRAY[0,0,0], 'Poteau AV-D', 'poteau');
  v_par_g := cad.add_piece(v_did, '90x90', 2400, ARRAY[0,2000,0],    ARRAY[0,0,0], 'Poteau AR-G', 'poteau');
  v_par_d := cad.add_piece(v_did, '90x90', 2400, ARRAY[2000,2000,0], ARRAY[0,0,0], 'Poteau AR-D', 'poteau');

  -- === TRAVERSES HAUTES (4 côtés) ===
  v_tav := cad.add_piece(v_did, '45x90', 2000, ARRAY[0,0,2400],    ARRAY[0,90,0],  'Traverse AV',  'traverse');
  v_tar := cad.add_piece(v_did, '45x90', 2000, ARRAY[0,2000,2400], ARRAY[0,90,0],  'Traverse AR',  'traverse');
  v_tg  := cad.add_piece(v_did, '90x45', 2000, ARRAY[0,0,2400],    ARRAY[0,0,-90], 'Traverse G',   'traverse');
  v_td  := cad.add_piece(v_did, '90x45', 2000, ARRAY[2000,0,2400], ARRAY[0,0,-90], 'Traverse D',   'traverse');

  -- === LISSES BASSES (4 côtés, au sol) ===
  v_lav := cad.add_piece(v_did, '45x90', 2000, ARRAY[0,0,0],       ARRAY[0,90,0], 'Lisse AV',  'lisse');
  v_lar := cad.add_piece(v_did, '45x90', 2000, ARRAY[0,2000,0],    ARRAY[0,90,0], 'Lisse AR',  'lisse');
  v_lg  := cad.add_piece(v_did, '90x45', 2000, ARRAY[0,0,0],       ARRAY[0,0,-90], 'Lisse G',   'lisse');
  v_ld  := cad.add_piece(v_did, '90x45', 2000, ARRAY[2000,0,0],    ARRAY[0,0,-90], 'Lisse D',   'lisse');

  -- === CHEVRONS (5 en toiture) ===
  v_c1 := cad.add_piece(v_did, '120x45', 2200, ARRAY[0,  -100,2445],  ARRAY[0,0,-90], 'Chevron 1', 'chevron');
  v_c2 := cad.add_piece(v_did, '120x45', 2200, ARRAY[500, -100,2445], ARRAY[0,0,-90], 'Chevron 2', 'chevron');
  v_c3 := cad.add_piece(v_did, '120x45', 2200, ARRAY[1000,-100,2445], ARRAY[0,0,-90], 'Chevron 3', 'chevron');
  v_c4 := cad.add_piece(v_did, '120x45', 2200, ARRAY[1500,-100,2445], ARRAY[0,0,-90], 'Chevron 4', 'chevron');
  v_c5 := cad.add_piece(v_did, '120x45', 2200, ARRAY[1880,-100,2445], ARRAY[0,0,-90], 'Chevron 5', 'chevron');

  -- === ENTRETOISES (2 diagonales face AV) ===
  PERFORM cad.add_piece(v_did, '45x45', 1200, ARRAY[45,0,1200],   ARRAY[0,45,0],  'Entretoise AV-G', 'montant');
  PERFORM cad.add_piece(v_did, '45x45', 1200, ARRAY[1955,0,1200], ARRAY[0,-45,0], 'Entretoise AV-D', 'montant');

  -- === GROUPES ===
  v_g_ossature := cad.group_pieces(v_did, ARRAY[v_tg, v_td], 'Ossature');

  v_g_face_av := cad.group_pieces(v_did, ARRAY[v_pav_g, v_pav_d, v_tav], 'Face avant');
  PERFORM cad.nest_group(v_g_face_av, v_g_ossature);

  v_g_face_ar := cad.group_pieces(v_did, ARRAY[v_par_g, v_par_d, v_tar], 'Face arrière');
  PERFORM cad.nest_group(v_g_face_ar, v_g_ossature);

  v_g_toiture := cad.group_pieces(v_did, ARRAY[v_c1, v_c2, v_c3, v_c4, v_c5], 'Toiture');
  v_g_lisses := cad.group_pieces(v_did, ARRAY[v_lav, v_lar, v_lg, v_ld], 'Lisses basses');

  RETURN '<template data-toast="success">Seed QA: abri bois (' || v_did || ') — 19 pièces, 5 groupes</template>'
    || '<template data-redirect="/"></template>';
END;
$function$;
