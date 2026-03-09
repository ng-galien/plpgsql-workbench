CREATE OR REPLACE FUNCTION docman.classify(p_doc_id uuid, p_doc_type text DEFAULT NULL::text, p_document_date date DEFAULT NULL::date, p_summary text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE docman.document
  SET doc_type = coalesce(p_doc_type, doc_type),
      document_date = coalesce(p_document_date, document_date),
      summary = coalesce(p_summary, summary),
      classified_at = now()
  WHERE id = p_doc_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'document not found: %', p_doc_id;
  END IF;
END;
$function$;
