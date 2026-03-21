CREATE OR REPLACE FUNCTION document.doc_create(p_name text, p_format text DEFAULT 'A4'::text, p_orientation text DEFAULT 'portrait'::text, p_charte_id text DEFAULT NULL::text, p_category text DEFAULT 'general'::text, p_html text DEFAULT ''::text, p_library_id text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_w numeric;
  v_h numeric;
  v_id text;
BEGIN
  CASE p_format
    WHEN 'A2' THEN v_w := 420; v_h := 594;
    WHEN 'A3' THEN v_w := 297; v_h := 420;
    WHEN 'A4' THEN v_w := 210; v_h := 297;
    WHEN 'A5' THEN v_w := 148; v_h := 210;
    WHEN 'HD' THEN v_w := 1920; v_h := 1080;
    WHEN 'MACBOOK' THEN v_w := 1440; v_h := 900;
    WHEN 'IPAD' THEN v_w := 1024; v_h := 768;
    WHEN 'MOBILE' THEN v_w := 390; v_h := 844;
    ELSE RAISE EXCEPTION 'Unknown format: %', p_format;
  END CASE;

  IF p_orientation = 'landscape' AND p_format LIKE 'A_' THEN
    v_w := v_w + v_h;
    v_h := v_w - v_h;
    v_w := v_w - v_h;
  END IF;

  IF p_charte_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM document.charte WHERE id = p_charte_id AND tenant_id = current_setting('app.tenant_id', true)) THEN
      RAISE EXCEPTION 'Charte not found: %', p_charte_id;
    END IF;
  END IF;

  INSERT INTO document.document (name, format, orientation, width, height, charte_id, category, library_id)
  VALUES (p_name, p_format, p_orientation, v_w, v_h, p_charte_id, p_category, p_library_id)
  RETURNING id INTO v_id;

  INSERT INTO document.page (doc_id, page_index, name, html)
  VALUES (v_id, 0, 'Page 1', COALESCE(p_html, ''));

  RETURN v_id;
END;
$function$;
