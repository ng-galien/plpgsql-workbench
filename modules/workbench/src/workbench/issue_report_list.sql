CREATE OR REPLACE FUNCTION workbench.issue_report_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(i) || jsonb_build_object(
        'message_subject', m.subject
      )
      FROM workbench.issue_report i
      LEFT JOIN workbench.agent_message m ON m.id = i.message_id
      ORDER BY i.id DESC;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(i) || jsonb_build_object(
        ''message_subject'', m.subject
      )
      FROM workbench.issue_report i
      LEFT JOIN workbench.agent_message m ON m.id = i.message_id
      WHERE ' || pgv.rsql_to_where(p_filter, 'workbench', 'issue_report')
      || ' ORDER BY i.id DESC';
  END IF;
END;
$function$;
