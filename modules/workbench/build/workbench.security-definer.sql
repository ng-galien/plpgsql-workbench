-- RFC-001: SECURITY DEFINER on all write functions
ALTER FUNCTION workbench.agent_message_create(workbench.agent_message) SECURITY DEFINER;
ALTER FUNCTION workbench.agent_message_update(workbench.agent_message) SECURITY DEFINER;
ALTER FUNCTION workbench.agent_message_delete(text) SECURITY DEFINER;
ALTER FUNCTION workbench.issue_report_create(workbench.issue_report) SECURITY DEFINER;
ALTER FUNCTION workbench.issue_report_update(workbench.issue_report) SECURITY DEFINER;
ALTER FUNCTION workbench.issue_report_delete(text) SECURITY DEFINER;
ALTER FUNCTION workbench.ack_resolved(text) SECURITY DEFINER;
ALTER FUNCTION workbench.inbox_new(text) SECURITY DEFINER;
ALTER FUNCTION workbench.log_hook(text, text, text, boolean, text) SECURITY DEFINER;
ALTER FUNCTION workbench.session_create(text, integer) SECURITY DEFINER;
ALTER FUNCTION workbench.session_end(integer, text) SECURITY DEFINER;

-- Revoke write grants on tables, keep SELECT
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA workbench FROM anon;
GRANT SELECT ON ALL TABLES IN SCHEMA workbench TO anon;
