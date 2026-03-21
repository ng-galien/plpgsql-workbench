CREATE OR REPLACE FUNCTION document.page_set_html(p_doc_id text, p_page_index integer, p_html text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_old_html text;
  v_version int;
  v_count int;
BEGIN
  -- Get current HTML
  SELECT html INTO v_old_html FROM document.page WHERE doc_id = p_doc_id AND page_index = p_page_index;
  IF v_old_html IS NULL THEN
    RAISE EXCEPTION 'Page not found: doc=% page=%', p_doc_id, p_page_index;
  END IF;

  -- Save revision (if there's actual content to save)
  IF v_old_html != '' THEN
    SELECT COALESCE(MAX(version), 0) + 1 INTO v_version
    FROM document.page_revision WHERE doc_id = p_doc_id AND page_index = p_page_index;

    INSERT INTO document.page_revision (doc_id, page_index, version, html)
    VALUES (p_doc_id, p_page_index, v_version, v_old_html);
  END IF;

  -- Update HTML
  UPDATE document.page SET html = p_html WHERE doc_id = p_doc_id AND page_index = p_page_index;

  -- Update document timestamp
  UPDATE document.document SET updated_at = now() WHERE id = p_doc_id;

  -- Count data-id elements
  SELECT count(*)::int INTO v_count FROM regexp_matches(p_html, 'data-id="[^"]*"', 'g');

  RETURN v_count;
END;
$function$;
