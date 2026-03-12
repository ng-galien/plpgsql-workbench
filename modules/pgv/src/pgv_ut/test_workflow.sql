CREATE OR REPLACE FUNCTION pgv_ut.test_workflow()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
  v_steps jsonb := '[{"key":"draft","label":"Brouillon"},{"key":"sent","label":"Envoyé"},{"key":"paid","label":"Payé"}]';
BEGIN
  -- Current at middle
  v_html := pgv.workflow(v_steps, 'sent');
  RETURN NEXT ok(v_html LIKE '%class="pgv-wf"%', 'container class pgv-wf');
  RETURN NEXT ok(v_html LIKE '%pgv-wf-done%', 'past step has done class');
  RETURN NEXT ok(v_html LIKE '%pgv-wf-current%', 'current step highlighted');
  RETURN NEXT ok(v_html LIKE '%pgv-wf-future%', 'future step marked');
  RETURN NEXT ok(v_html LIKE '%pgv-wf-line-done%', 'done connector line');
  RETURN NEXT ok(v_html LIKE '%Brouillon%', 'label rendered');
  RETURN NEXT ok(v_html LIKE '%pgv-wf-dot%', 'dot elements present');

  -- Current at first
  v_html := pgv.workflow(v_steps, 'draft');
  RETURN NEXT ok(v_html NOT LIKE '%pgv-wf-done%', 'no done steps when current is first');
  RETURN NEXT ok(v_html LIKE '%pgv-wf-current%', 'first step is current');

  -- Current at last
  v_html := pgv.workflow(v_steps, 'paid');
  RETURN NEXT ok(v_html NOT LIKE '%pgv-wf-future%', 'no future steps when current is last');
  RETURN NEXT ok((SELECT count(*) FROM regexp_matches(v_html, 'pgv-wf-done', 'g')) = 2, 'two done steps before last');

  -- XSS
  v_html := pgv.workflow('[{"key":"a","label":"<script>alert(1)</script>"}]', 'a');
  RETURN NEXT ok(v_html NOT LIKE '%<script>%', 'labels escaped');
END;
$function$;
