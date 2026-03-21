-- Tag MCP-exposed functions with SET api.expose = 'mcp'

-- CRUD: charte
ALTER FUNCTION docs.charte_create(docs.charte) SET api.expose = 'mcp';
ALTER FUNCTION docs.charte_read(text) SET api.expose = 'mcp';
ALTER FUNCTION docs.charte_list(text) SET api.expose = 'mcp';
ALTER FUNCTION docs.charte_update(docs.charte) SET api.expose = 'mcp';
ALTER FUNCTION docs.charte_delete(text) SET api.expose = 'mcp';

-- CRUD: document
ALTER FUNCTION docs.document_create(docs.document) SET api.expose = 'mcp';
ALTER FUNCTION docs.document_read(text) SET api.expose = 'mcp';
ALTER FUNCTION docs.document_list(text) SET api.expose = 'mcp';
ALTER FUNCTION docs.document_update(docs.document) SET api.expose = 'mcp';
ALTER FUNCTION docs.document_delete(text) SET api.expose = 'mcp';

-- CRUD: library
ALTER FUNCTION docs.library_create(docs.library) SET api.expose = 'mcp';
ALTER FUNCTION docs.library_read(text) SET api.expose = 'mcp';
ALTER FUNCTION docs.library_list(text) SET api.expose = 'mcp';
ALTER FUNCTION docs.library_delete(text) SET api.expose = 'mcp';

-- Methods
ALTER FUNCTION docs.charte_tokens_to_css(text) SET api.expose = 'mcp';
ALTER FUNCTION docs.charte_check(text, text) SET api.expose = 'mcp';
ALTER FUNCTION docs.document_duplicate(text, text) SET api.expose = 'mcp';
ALTER FUNCTION docs.document_print_css(text) SET api.expose = 'mcp';
ALTER FUNCTION docs.layout_check(text, numeric, numeric) SET api.expose = 'mcp';
ALTER FUNCTION docs.xhtml_patch(text, jsonb) SET api.expose = 'mcp';
ALTER FUNCTION docs.xhtml_validate(text) SET api.expose = 'mcp';
ALTER FUNCTION docs.style_merge(text, text) SET api.expose = 'mcp';
ALTER FUNCTION docs.normalize_color(text) SET api.expose = 'mcp';
ALTER FUNCTION docs.page_add(text, text, text) SET api.expose = 'mcp';
ALTER FUNCTION docs.page_remove(text, integer) SET api.expose = 'mcp';
ALTER FUNCTION docs.page_set_html(text, integer, text) SET api.expose = 'mcp';
ALTER FUNCTION docs.library_add_asset(text, uuid, text, text, integer) SET api.expose = 'mcp';
ALTER FUNCTION docs.library_remove_asset(text, uuid) SET api.expose = 'mcp';
