CREATE OR REPLACE FUNCTION workbench.agent_message_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(m) || jsonb_build_object(
        'issue_id', ir.id,
        'issue_type', ir.issue_type
      )
      FROM workbench.agent_message m
      LEFT JOIN workbench.issue_report ir ON ir.message_id = m.id
      ORDER BY m.id DESC;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(m) || jsonb_build_object(
        ''issue_id'', ir.id,
        ''issue_type'', ir.issue_type
      )
      FROM workbench.agent_message m
      LEFT JOIN workbench.issue_report ir ON ir.message_id = m.id
      WHERE ' || pgv.rsql_to_where(p_filter, 'workbench', 'agent_message')
      || ' ORDER BY m.id DESC';
  END IF;
END;
$function$;
