CREATE OR REPLACE FUNCTION document.doc_load(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_d document.document;
  v_css text;
  v_pages jsonb := '[]'::jsonb;
  r record;
BEGIN
  SELECT * INTO v_d FROM document.document WHERE id = p_id AND tenant_id = current_setting('app.tenant_id', true);
  IF v_d IS NULL THEN RETURN NULL; END IF;

  -- Charte CSS
  IF v_d.charte_id IS NOT NULL THEN
    v_css := document.charte_tokens_to_css(v_d.charte_id);
  END IF;

  -- Pages
  FOR r IN
    SELECT page_index, name, html, format, orientation, width, height, bg, text_margin
    FROM document.page WHERE doc_id = p_id ORDER BY page_index
  LOOP
    v_pages := v_pages || jsonb_build_object(
      'page_index', r.page_index,
      'name', r.name,
      'html', r.html,
      'format', r.format,
      'width', r.width,
      'height', r.height,
      'bg', r.bg
    );
  END LOOP;

  RETURN jsonb_build_object(
    'id', v_d.id,
    'name', v_d.name,
    'category', v_d.category,
    'format', v_d.format,
    'orientation', v_d.orientation,
    'width', v_d.width,
    'height', v_d.height,
    'bg', v_d.bg,
    'text_margin', v_d.text_margin,
    'status', v_d.status,
    'charte_id', v_d.charte_id,
    'charte_css', v_css,
    'pages', v_pages,
    'active_page', v_d.active_page,
    'rating', v_d.rating,
    'design_notes', v_d.design_notes
  );
END;
$function$;
