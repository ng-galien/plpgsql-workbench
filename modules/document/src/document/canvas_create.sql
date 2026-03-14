CREATE OR REPLACE FUNCTION document.canvas_create(p_name text, p_format text DEFAULT 'A4'::text, p_orientation text DEFAULT 'portrait'::text, p_width real DEFAULT NULL::real, p_height real DEFAULT NULL::real, p_bg text DEFAULT '#ffffff'::text, p_category text DEFAULT 'general'::text)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_w real := p_width;
  v_h real := p_height;
  v_id uuid;
BEGIN
  -- Default dimensions by format (mm -> px at 96dpi ≈ 3.78px/mm)
  IF v_w IS NULL OR v_h IS NULL THEN
    CASE p_format
      WHEN 'A2' THEN v_w := 1587; v_h := 2245;
      WHEN 'A3' THEN v_w := 1123; v_h := 1587;
      WHEN 'A4' THEN v_w := 794;  v_h := 1123;
      WHEN 'A5' THEN v_w := 559;  v_h := 794;
      WHEN 'HD' THEN v_w := 1920; v_h := 1080;
      WHEN 'MACBOOK' THEN v_w := 1440; v_h := 900;
      WHEN 'IPAD' THEN v_w := 1024; v_h := 1366;
      WHEN 'MOBILE' THEN v_w := 390; v_h := 844;
      ELSE v_w := 794; v_h := 1123; -- default A4
    END CASE;
  END IF;

  -- Swap for landscape
  IF p_orientation = 'paysage' AND v_w < v_h THEN
    v_w := v_w + v_h;
    v_h := v_w - v_h;
    v_w := v_w - v_h;
  END IF;

  INSERT INTO document.canvas (name, format, orientation, width, height, background, category)
  VALUES (p_name, p_format, p_orientation, v_w, v_h, p_bg, p_category)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$function$;
