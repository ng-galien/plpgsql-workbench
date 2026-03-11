CREATE OR REPLACE FUNCTION cad_qa.get_drawing_bom(p_id integer)
 RETURNS "text/html"
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_body text;
  v_rows text[];
  v_rec record;
  v_total_count int := 0;
  v_total_vol numeric := 0;
BEGIN
  -- Default to first drawing when no id provided
  IF p_id IS NULL THEN
    SELECT id INTO p_id FROM cad.drawing ORDER BY name LIMIT 1;
    IF p_id IS NULL THEN
      RETURN pgv.empty('Aucun dessin', 'Lancez le seed pour créer des données.');
    END IF;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM cad.drawing WHERE id = p_id) THEN
    RETURN pgv.error('404', 'Dessin non trouvé');
  END IF;

  v_body := cad.fragment_drawing_nav(p_id, 'Liste de débit');

  -- BOM table grouped by role/section
  v_rows := ARRAY[]::text[];
  FOR v_rec IN
    SELECT
      p.role, p.section, p.wood_type,
      count(*) AS qty,
      round(sum(p.length_mm)::numeric) AS total_len,
      round((sum(ST_Volume(p.geom)) / 1e9)::numeric, 6) AS total_vol,
      COALESCE(g.label, '-') AS grp_label
    FROM cad.piece p
    LEFT JOIN cad.piece_group g ON g.id = p.group_id
    WHERE p.drawing_id = p_id
    GROUP BY p.role, p.section, p.wood_type, g.label
    ORDER BY g.label NULLS LAST, p.role, p.section
  LOOP
    v_rows := v_rows || ARRAY[
      v_rec.qty::text,
      v_rec.section,
      v_rec.wood_type,
      v_rec.role,
      v_rec.total_len || ' mm',
      v_rec.total_vol || ' m³',
      v_rec.grp_label
    ];
    v_total_count := v_total_count + v_rec.qty;
    v_total_vol := v_total_vol + v_rec.total_vol;
  END LOOP;

  IF array_length(v_rows, 1) > 0 THEN
    v_body := v_body || '<section>' || pgv.md_table(
      ARRAY['Qté', 'Section', 'Essence', 'Rôle', 'Longueur', 'Volume', 'Groupe'],
      v_rows
    ) || pgv.grid(
      pgv.stat('Pièces', v_total_count::text),
      pgv.stat('Volume total', round(v_total_vol, 4) || ' m³')
    ) || '</section>';
  ELSE
    v_body := v_body || '<section>' || pgv.empty('Aucune pièce', 'Ce dessin ne contient pas de pièces 3D.') || '</section>';
  END IF;

  RETURN v_body;
END;
$function$;
