CREATE OR REPLACE FUNCTION cad_qa.get_index()
 RETURNS "text/html"
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_body text := '';
  v_rec record;
  v_cards text := '';
BEGIN
  -- Drawing cards
  FOR v_rec IN
    SELECT d.id, d.name,
      (SELECT count(*) FROM cad.piece WHERE drawing_id = d.id) AS piece_count,
      COALESCE((SELECT round((sum(ST_Volume(geom)) / 1e9)::numeric, 4) FROM cad.piece WHERE drawing_id = d.id), 0) AS vol
    FROM cad.drawing d
    ORDER BY d.name
  LOOP
    v_cards := v_cards || pgv.card(
      '<a href="' || pgv.call_ref('get_drawing', jsonb_build_object('p_id', v_rec.id)) || '">'
        || pgv.esc(v_rec.name) || '</a>',
      '<p>'
        || pgv.badge(v_rec.piece_count || ' pièces')
        || CASE WHEN v_rec.vol > 0 THEN ' ' || pgv.badge(v_rec.vol || ' m³', 'success') ELSE '' END
        || '</p>',
      '<a href="' || pgv.call_ref('get_drawing', jsonb_build_object('p_id', v_rec.id)) || '">2D</a>'
        || ' · <a href="' || pgv.call_ref('get_drawing_3d', jsonb_build_object('p_id', v_rec.id)) || '">3D</a>'
        || ' · <a href="' || pgv.call_ref('get_drawing_bom', jsonb_build_object('p_id', v_rec.id)) || '">Débit</a>'
    );
  END LOOP;

  IF v_cards = '' THEN
    v_body := '<section>' || pgv.empty('Aucun dessin', 'Cliquez "Recréer le seed QA" pour générer les données de démo.') || '</section>';
  ELSE
    v_body := '<section>' || pgv.grid(v_cards) || '</section>';
  END IF;

  v_body := v_body || '<section>' || pgv.action('seed', 'Recréer le seed QA', '{}'::jsonb, 'Recréer l''abri bois de démo ?') || '</section>';

  RETURN v_body;
END;
$function$;
