CREATE OR REPLACE FUNCTION pgv.post_bug_report(p jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_desc text;
  v_ctx  jsonb;
BEGIN
  v_desc := trim(p->>'description');
  IF v_desc IS NULL OR v_desc = '' THEN
    RETURN '<template data-toast="error">Description requise</template>';
  END IF;

  -- Build context from remaining keys
  v_ctx := p - 'description';

  INSERT INTO workbench.bug_report (description, context)
  VALUES (v_desc, v_ctx);

  RETURN '<template data-toast="success">Bug reporté, merci !</template>';
END;
$function$;
