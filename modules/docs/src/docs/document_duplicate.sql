CREATE OR REPLACE FUNCTION docs.document_duplicate(p_source_id text, p_new_name text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_src docs.document;
  v_id text;
BEGIN
  SELECT * INTO v_src FROM docs.document
  WHERE id = p_source_id AND tenant_id = current_setting('app.tenant_id', true);
  IF v_src IS NULL THEN RAISE EXCEPTION 'Document not found: %', p_source_id; END IF;

  INSERT INTO docs.document (name, category, charte_id, format, orientation, width, height, bg, text_margin, design_notes)
  VALUES (p_new_name, v_src.category, v_src.charte_id, v_src.format, v_src.orientation, v_src.width, v_src.height, v_src.bg, v_src.text_margin, v_src.design_notes)
  RETURNING id INTO v_id;

  INSERT INTO docs.page (doc_id, page_index, name, html, format, orientation, width, height, bg, text_margin)
  SELECT v_id, page_index, name, html, format, orientation, width, height, bg, text_margin
  FROM docs.page WHERE doc_id = p_source_id ORDER BY page_index;

  RETURN v_id;
END;
$function$;
