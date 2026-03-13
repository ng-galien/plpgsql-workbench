CREATE OR REPLACE FUNCTION pgv.doc(p_topic text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_content text;
BEGIN
  SELECT content INTO v_content FROM workbench.doc WHERE topic = p_topic;
  IF NOT FOUND THEN
    RETURN pgv.empty('Document introuvable', 'Topic: ' || pgv.esc(p_topic));
  END IF;
  RETURN '<md>' || v_content || '</md>';
END;
$function$;
