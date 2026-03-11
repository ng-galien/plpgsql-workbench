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

  -- 3D viewer (premier dessin avec des pièces)
  SELECT d.id INTO v_did
  FROM cad.drawing d
  WHERE EXISTS (SELECT 1 FROM cad.piece WHERE drawing_id = d.id)
  ORDER BY d.id LIMIT 1;

  IF v_did IS NOT NULL THEN
    v_body := v_body || '<h3>Vue 3D</h3>' || cad.fragment_viewer(v_did);
    v_body := v_body || '<h3>Wireframe</h3>' || cad.render_wireframe(v_did, 'front', 800, 500);
    v_body := v_body || '<h3>Liste de débit</h3>' || cad.bill_of_materials(v_did);
  ELSE
    v_body := v_body || pgv.error('info', 'Pas de pièces 3D', 'Cliquez "Recréer le seed QA" pour générer les données de démo.');
  END IF;

  RETURN v_body;
END;
$function$;
