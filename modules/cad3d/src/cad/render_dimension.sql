CREATE OR REPLACE FUNCTION cad.render_dimension(p_g jsonb, p_unit text DEFAULT 'mm'::text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_x1 real := (p_g->>'x1')::real;
  v_y1 real := (p_g->>'y1')::real;
  v_x2 real := (p_g->>'x2')::real;
  v_y2 real := (p_g->>'y2')::real;
  v_offset real := COALESCE((p_g->>'offset')::real, 20);
  v_dist real;
  v_mx real; v_my real;
  v_dx real; v_dy real; v_len real;
  v_nx real; v_ny real;
  v_ox1 real; v_oy1 real; v_ox2 real; v_oy2 real;
BEGIN
  -- Distance entre les deux points
  v_dist := sqrt((v_x2-v_x1)^2 + (v_y2-v_y1)^2);

  -- Vecteur direction normalisé
  v_dx := v_x2 - v_x1;
  v_dy := v_y2 - v_y1;
  v_len := sqrt(v_dx^2 + v_dy^2);
  IF v_len = 0 THEN RETURN ''; END IF;

  -- Normal perpendiculaire
  v_nx := -v_dy / v_len * v_offset;
  v_ny :=  v_dx / v_len * v_offset;

  -- Points de la ligne de cote (décalée)
  v_ox1 := v_x1 + v_nx; v_oy1 := v_y1 + v_ny;
  v_ox2 := v_x2 + v_nx; v_oy2 := v_y2 + v_ny;

  -- Milieu pour le texte
  v_mx := (v_ox1 + v_ox2) / 2;
  v_my := (v_oy1 + v_oy2) / 2;

  RETURN
    -- Lignes d'attache
    format('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke-dasharray="4 2"/>',
      v_x1, v_y1, v_ox1, v_oy1)
    || format('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke-dasharray="4 2"/>',
      v_x2, v_y2, v_ox2, v_oy2)
    -- Ligne de cote
    || format('<line x1="%s" y1="%s" x2="%s" y2="%s" marker-start="url(#arrow)" marker-end="url(#arrow)"/>',
      v_ox1, v_oy1, v_ox2, v_oy2)
    -- Texte de la mesure
    || format('<text x="%s" y="%s" font-size="12" text-anchor="middle" fill="currentColor" stroke="none" dy="-4">%s %s</text>',
      v_mx, v_my, round(v_dist::numeric, 1), p_unit);
END;
$function$;
