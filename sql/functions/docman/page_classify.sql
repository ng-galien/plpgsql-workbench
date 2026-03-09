CREATE OR REPLACE FUNCTION docman.page_classify(p_doc_id uuid, p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_doc jsonb;
  v_body text;
  v_types jsonb;
BEGIN
  v_doc := docman.peek(p_doc_id);

  IF v_doc ? 'error' THEN
    RETURN pgv.page('Erreur', '/docs', app.nav_items(), '<p>Document non trouve.</p>');
  END IF;

  -- If POST with data, apply classification
  IF p_body->>'p_doc_type' IS NOT NULL OR p_body->>'p_summary' IS NOT NULL THEN
    PERFORM docman.classify(
      p_doc_id,
      nullif(p_body->>'p_doc_type', ''),
      nullif(p_body->>'p_document_date', '')::date,
      nullif(p_body->>'p_summary', '')
    );
    -- Redirect to detail page
    PERFORM set_config('response.headers', '[{"HX-Redirect": "/rpc/page?p_path=/docs/' || p_doc_id || '"}]', true);
    RETURN ''::text::"text/html";
  END IF;

  -- Collect known doc_types for select
  SELECT coalesce(jsonb_agg(to_jsonb(dt.doc_type)), '[]'::jsonb)
  INTO v_types
  FROM (SELECT DISTINCT doc_type FROM docman.document WHERE doc_type IS NOT NULL ORDER BY doc_type) dt;

  v_body := pgv.card(
    'Classifier : ' || pgv.esc(v_doc->>'filename'),
    '<form hx-post="/rpc/page_classify" hx-target="#app">'
      || '<input type="hidden" name="p_doc_id" value="' || p_doc_id || '">'
      || pgv.sel('p_doc_type', 'Type de document', v_types, v_doc->>'doc_type')
      || pgv.input('p_document_date', 'date', 'Date du document', v_doc->>'document_date')
      || pgv.textarea('p_summary', 'Resume', v_doc->>'summary', 4)
      || '<button type="submit">Enregistrer</button>'
      || '</form>'
  );

  RETURN pgv.page('Classifier', '/docs/' || p_doc_id || '/classify', app.nav_items(), v_body);
END;
$function$;
