CREATE OR REPLACE FUNCTION docs.document_update(p_data docs.document)
 RETURNS docs.document
 LANGUAGE plpgsql
 SET "api.expose" TO 'mcp'
AS $function$
BEGIN
  IF p_data.name IS NOT NULL AND p_data.name != '' THEN
    p_data.slug := pgv.slugify(COALESCE(p_data.category, ''), p_data.name);
  END IF;

  UPDATE docs.document SET
    name = COALESCE(NULLIF(p_data.name, ''), name),
    slug = COALESCE(NULLIF(p_data.slug, ''), slug),
    category = COALESCE(NULLIF(p_data.category, ''), category),
    charte_id = COALESCE(p_data.charte_id, charte_id),
    bg = COALESCE(NULLIF(p_data.bg, ''), bg),
    text_margin = COALESCE(p_data.text_margin, text_margin),
    design_notes = COALESCE(p_data.design_notes, design_notes),
    team_notes = COALESCE(p_data.team_notes, team_notes),
    rating = COALESCE(p_data.rating, rating),
    email_to = COALESCE(p_data.email_to, email_to),
    email_cc = COALESCE(p_data.email_cc, email_cc),
    email_bcc = COALESCE(p_data.email_bcc, email_bcc),
    email_subject = COALESCE(p_data.email_subject, email_subject),
    ref_module = COALESCE(p_data.ref_module, ref_module),
    ref_id = COALESCE(p_data.ref_id, ref_id),
    status = COALESCE(NULLIF(p_data.status, ''), status),
    active_page = COALESCE(p_data.active_page, active_page),
    library_id = COALESCE(p_data.library_id, library_id),
    updated_at = now()
  WHERE (slug = p_data.slug OR id = p_data.id) AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_data;
  RETURN p_data;
END;
$function$;
