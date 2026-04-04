CREATE OR REPLACE FUNCTION pgv.post_issue_report(p jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_desc text;
  v_type text;
  v_module text;
  v_ctx  jsonb;
BEGIN
  v_desc := trim(p->>'description');
  IF v_desc IS NULL OR v_desc = '' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'message', pgv.t('issue.error')
    );
  END IF;

  v_type := coalesce(p->>'issue_type', 'bug');
  IF v_type NOT IN ('bug', 'enhancement', 'question') THEN
    v_type := 'bug';
  END IF;

  v_module := p->>'schema';

  -- Build context from remaining keys
  v_ctx := p - 'description' - 'issue_type' - 'schema';

  INSERT INTO workbench.issue_report (description, issue_type, module, context)
  VALUES (v_desc, v_type, v_module, v_ctx);

  RETURN jsonb_build_object(
    'ok', true,
    'message', pgv.t('issue.success'),
    'issue_type', v_type,
    'module', v_module
  );
END;
$function$;
