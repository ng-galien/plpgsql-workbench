CREATE OR REPLACE FUNCTION cad_qa.get_index()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_did int;
BEGIN
  -- Stats
  v_body := pgv.grid(
    pgv.stat('Dessins', (SELECT count(*)::text FROM cad.drawing), 'total'),
    pgv.stat('Shapes', (SELECT count(*)::text FROM cad.shape), 'total'),
    pgv.stat('Calques', (SELECT count(*)::text FROM cad.layer), 'total'),
    pgv.stat('Pièces 3D', (SELECT count(*)::text FROM cad.piece), 'total')
  );

  -- Seed button
  v_body := v_body || pgv.action('seed', 'Recréer le seed QA', '{}'::jsonb, 'Recréer l''abri bois de démo ?');

  -- Premier dessin avec des pièces
  SELECT d.id INTO v_did
  FROM cad.drawing d
  WHERE EXISTS (SELECT 1 FROM cad.piece WHERE drawing_id = d.id)
  ORDER BY d.id LIMIT 1;

  IF v_did IS NOT NULL THEN
    -- Navigation vers les pages dessin (même schema cad_qa)
    v_body := v_body || '<h3>Dessin #' || v_did || '</h3>'
      || '<p>'
      || '<a href="' || pgv.call_ref('get_drawing', jsonb_build_object('p_id', v_did)) || '">Vue 2D</a>'
      || ' | <a href="' || pgv.call_ref('get_drawing_3d', jsonb_build_object('p_id', v_did)) || '">Vue 3D</a>'
      || ' | <a href="' || pgv.call_ref('get_drawing_bom', jsonb_build_object('p_id', v_did)) || '">Liste de débit</a>'
      || '</p>';

    -- Aperçu 3D
    v_body := v_body || cad.fragment_viewer(v_did);
  ELSE
    v_body := v_body || pgv.error('info', 'Pas de pièces 3D', 'Cliquez "Recréer le seed QA" pour générer les données de démo.');
  END IF;

  RETURN v_body;
END;
$function$;
