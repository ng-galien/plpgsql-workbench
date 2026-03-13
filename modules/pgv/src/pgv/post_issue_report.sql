CREATE OR REPLACE FUNCTION pgv.post_issue_report(p jsonb DEFAULT '{}'::jsonb)
 RETURNS text
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
    RETURN pgv.toast(pgv.t('issue.error'), 'error');
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

  RETURN pgv.toast(pgv.t('issue.success'));
END;
$function$;
