CREATE OR REPLACE FUNCTION docman.untag(p_doc_id uuid, p_label_id integer)
 RETURNS void
 LANGUAGE sql
AS $function$
  DELETE FROM docman.document_label
  WHERE document_id = p_doc_id AND label_id = p_label_id;
$function$;
