-- RFC-001: SECURITY DEFINER on all write functions
ALTER FUNCTION docs.charte_create(docs.charte) SECURITY DEFINER;
ALTER FUNCTION docs.charte_update(docs.charte) SECURITY DEFINER;
ALTER FUNCTION docs.charte_delete(text) SECURITY DEFINER;
ALTER FUNCTION docs.document_create(docs.document) SECURITY DEFINER;
ALTER FUNCTION docs.document_update(docs.document) SECURITY DEFINER;
ALTER FUNCTION docs.document_delete(text) SECURITY DEFINER;
ALTER FUNCTION docs.document_duplicate(text, text) SECURITY DEFINER;
ALTER FUNCTION docs.library_create(docs.library) SECURITY DEFINER;
ALTER FUNCTION docs.library_update(docs.library) SECURITY DEFINER;
ALTER FUNCTION docs.library_delete(text) SECURITY DEFINER;
ALTER FUNCTION docs.library_add_asset(text, uuid, text, text, integer) SECURITY DEFINER;
ALTER FUNCTION docs.library_remove_asset(text, uuid) SECURITY DEFINER;
ALTER FUNCTION docs.page_set_html(text, integer, text) SECURITY DEFINER;
ALTER FUNCTION docs.page_add(text, text, text) SECURITY DEFINER;
ALTER FUNCTION docs.page_remove(text, integer) SECURITY DEFINER;
ALTER FUNCTION docs.xhtml_patch(text, jsonb) SECURITY DEFINER;

-- RFC-001: REVOKE write grants, keep SELECT only for anon
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA docs FROM anon;
GRANT SELECT ON ALL TABLES IN SCHEMA docs TO anon;
GRANT USAGE ON SCHEMA docs TO anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA docs TO anon;
