CREATE OR REPLACE FUNCTION docs.doc_load(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_d docs.document;
  v_css text;
  v_pages jsonb := '[]'::jsonb;
  v_library jsonb;
  r record;
BEGIN
  SELECT * INTO v_d FROM docs.document WHERE id = p_id AND tenant_id = current_setting('app.tenant_id', true);
  IF v_d IS NULL THEN RETURN NULL; END IF;

  IF v_d.charte_id IS NOT NULL THEN
    v_css := docs.charte_tokens_to_css(v_d.charte_id);
  END IF;

  IF v_d.library_id IS NOT NULL THEN
    v_library := docs.library_load(v_d.library_id);
  END IF;

  FOR r IN
    SELECT page_index, name, html, format, orientation, width, height, bg, text_margin
    FROM docs.page WHERE doc_id = p_id ORDER BY page_index
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
    'library_id', v_d.library_id,
    'library', v_library,
    'pages', v_pages,
    'active_page', v_d.active_page,
    'rating', v_d.rating,
    'design_notes', v_d.design_notes
  );
END;
$function$;
