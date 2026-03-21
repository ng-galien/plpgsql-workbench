CREATE OR REPLACE FUNCTION docs.document_create(p_data docs.document)
 RETURNS docs.document
 LANGUAGE plpgsql
AS $function$
BEGIN
  CASE COALESCE(p_data.format, 'A4')
    WHEN 'A2' THEN p_data.width := 420; p_data.height := 594;
    WHEN 'A3' THEN p_data.width := 297; p_data.height := 420;
    WHEN 'A4' THEN p_data.width := 210; p_data.height := 297;
    WHEN 'A5' THEN p_data.width := 148; p_data.height := 210;
    WHEN 'HD' THEN p_data.width := 1920; p_data.height := 1080;
    WHEN 'MACBOOK' THEN p_data.width := 1440; p_data.height := 900;
    WHEN 'IPAD' THEN p_data.width := 1024; p_data.height := 768;
    WHEN 'MOBILE' THEN p_data.width := 390; p_data.height := 844;
    ELSE RAISE EXCEPTION 'Unknown format: %', p_data.format;
  END CASE;

  IF COALESCE(p_data.orientation, 'portrait') = 'landscape' AND COALESCE(p_data.format, 'A4') LIKE 'A_' THEN
    p_data.width := p_data.width + p_data.height;
    p_data.height := p_data.width - p_data.height;
    p_data.width := p_data.width - p_data.height;
  END IF;

  IF p_data.charte_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM docs.charte WHERE id = p_data.charte_id AND tenant_id = current_setting('app.tenant_id', true)) THEN
      RAISE EXCEPTION 'Charte not found: %', p_data.charte_id;
    END IF;
  END IF;

  p_data.id := gen_random_uuid()::text;
  p_data.tenant_id := current_setting('app.tenant_id', true);
  p_data.category := COALESCE(p_data.category, 'general');
  p_data.slug := pgv.slugify(p_data.category, p_data.name);
  p_data.format := COALESCE(p_data.format, 'A4');
  p_data.orientation := COALESCE(p_data.orientation, 'portrait');
  p_data.bg := COALESCE(p_data.bg, '#ffffff');
  p_data.text_margin := COALESCE(p_data.text_margin, 10);
  p_data.status := COALESCE(p_data.status, 'draft');
  p_data.rating := COALESCE(p_data.rating, 0);
  p_data.active_page := COALESCE(p_data.active_page, 0);
  p_data.created_at := now();
  p_data.updated_at := now();

  INSERT INTO docs.document VALUES (p_data.*) RETURNING * INTO p_data;

  INSERT INTO docs.page (doc_id, page_index, name, html)
  VALUES (p_data.id, 0, 'Page 1', '');

  RETURN p_data;
END;
$function$;
