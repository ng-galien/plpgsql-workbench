CREATE OR REPLACE FUNCTION ops.get_messages(p_module text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_rows text[];
  v_body text;
  r record;
  v_type_variant text;
  v_status_variant text;
BEGIN
  v_rows := ARRAY[]::text[];

  FOR r IN
    SELECT m.id, m.from_module, m.to_module, m.msg_type, m.subject, m.status,
           to_char(m.created_at, 'DD/MM HH24:MI') AS dt
      FROM workbench.agent_message m
     WHERE (p_module IS NULL OR m.from_module = p_module OR m.to_module = p_module)
     ORDER BY m.created_at DESC
  LOOP
    v_type_variant := CASE r.msg_type
      WHEN 'feature_request' THEN 'info'
      WHEN 'bug_report' THEN 'danger'
      WHEN 'question' THEN 'warning'
      ELSE 'default'
    END;
    v_status_variant := CASE r.status
      WHEN 'new' THEN 'warning'
      WHEN 'acknowledged' THEN 'info'
      WHEN 'resolved' THEN 'success'
      ELSE 'default'
    END;

    v_rows := v_rows || ARRAY[
      '#' || r.id::text,
      pgv.badge(r.from_module, 'default'),
      pgv.badge(r.to_module, 'default'),
      pgv.badge(r.msg_type, v_type_variant),
      pgv.esc(r.subject),
      pgv.badge(r.status, v_status_variant),
      r.dt
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := pgv.empty('Aucun message', 'Les messages inter-agents apparaitront ici.');
  ELSE
    v_body := pgv.md_table(
      ARRAY['#', 'De', 'A', 'Type', 'Sujet', 'Status', 'Date'],
      v_rows,
      20
    );
  END IF;

  RETURN v_body;
END;
$function$;
