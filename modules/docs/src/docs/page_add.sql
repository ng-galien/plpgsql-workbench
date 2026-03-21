CREATE OR REPLACE FUNCTION docs.page_add(p_doc_id text, p_name text DEFAULT NULL::text, p_html text DEFAULT ''::text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_idx integer;
BEGIN
  SELECT COALESCE(MAX(page_index), -1) + 1 INTO v_idx FROM docs.page WHERE doc_id = p_doc_id;

  INSERT INTO docs.page (doc_id, page_index, name, html)
  VALUES (p_doc_id, v_idx, COALESCE(p_name, 'Page ' || (v_idx + 1)::text), COALESCE(p_html, ''));

  RETURN v_idx;
END;
$function$;
