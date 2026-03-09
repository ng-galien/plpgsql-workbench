CREATE OR REPLACE FUNCTION docman.unlink(p_doc_id uuid, p_entity_id integer, p_role text)
 RETURNS void
 LANGUAGE sql
AS $function$
  DELETE FROM docman.document_entity
  WHERE document_id = p_doc_id AND entity_id = p_entity_id AND role = p_role;
$function$;
