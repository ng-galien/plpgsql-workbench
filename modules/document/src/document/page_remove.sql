CREATE OR REPLACE FUNCTION document.page_remove(p_doc_id text, p_page_index integer)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_total int;
  v_active int;
BEGIN
  SELECT count(*)::int INTO v_total FROM document.page WHERE doc_id = p_doc_id;
  IF v_total <= 1 THEN
    RAISE EXCEPTION 'Cannot remove the last page';
  END IF;

  DELETE FROM document.page WHERE doc_id = p_doc_id AND page_index = p_page_index;
  IF NOT FOUND THEN RETURN false; END IF;

  -- Renumber pages after the removed one
  UPDATE document.page SET page_index = page_index - 1
  WHERE doc_id = p_doc_id AND page_index > p_page_index;

  -- Adjust active_page if needed
  SELECT active_page INTO v_active FROM document.document WHERE id = p_doc_id;
  IF v_active >= v_total - 1 THEN
    UPDATE document.document SET active_page = greatest(0, v_total - 2) WHERE id = p_doc_id;
  ELSIF v_active > p_page_index THEN
    UPDATE document.document SET active_page = v_active - 1 WHERE id = p_doc_id;
  END IF;

  RETURN true;
END;
$function$;
