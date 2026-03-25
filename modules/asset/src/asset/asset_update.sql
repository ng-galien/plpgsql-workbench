CREATE OR REPLACE FUNCTION asset.asset_update(p_row asset.asset)
 RETURNS asset.asset
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE asset.asset SET
    path        = COALESCE(NULLIF(p_row.path, ''), path),
    filename    = COALESCE(NULLIF(p_row.filename, ''), filename),
    mime_type   = COALESCE(NULLIF(p_row.mime_type, ''), mime_type),
    status      = COALESCE(NULLIF(p_row.status, ''), status),
    width       = COALESCE(p_row.width, width),
    height      = COALESCE(p_row.height, height),
    orientation = COALESCE(p_row.orientation, orientation),
    title       = COALESCE(p_row.title, title),
    description = COALESCE(p_row.description, description),
    tags        = COALESCE(p_row.tags, tags),
    credit      = COALESCE(p_row.credit, credit),
    saison      = COALESCE(p_row.saison, saison),
    usage_hint  = COALESCE(p_row.usage_hint, usage_hint),
    colors      = COALESCE(p_row.colors, colors),
    thumb_path  = COALESCE(p_row.thumb_path, thumb_path),
    classified_at = COALESCE(p_row.classified_at, classified_at)
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_row;
  RETURN p_row;
END;
$function$;
