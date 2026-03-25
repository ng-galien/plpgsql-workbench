CREATE OR REPLACE FUNCTION asset.asset_create(p_row asset.asset)
 RETURNS asset.asset
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  p_row.id := COALESCE(p_row.id, gen_random_uuid());
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.status := COALESCE(p_row.status, 'to_classify');
  p_row.mime_type := COALESCE(p_row.mime_type, 'image/jpeg');
  p_row.tags := COALESCE(p_row.tags, '{}');
  p_row.colors := COALESCE(p_row.colors, '{}');
  p_row.created_at := COALESCE(p_row.created_at, now());

  INSERT INTO asset.asset (id, tenant_id, path, filename, mime_type, status,
    width, height, orientation, title, description, tags, credit, season,
    usage_hint, colors, thumb_path, created_at, classified_at)
  VALUES (p_row.id, p_row.tenant_id, p_row.path, p_row.filename, p_row.mime_type, p_row.status,
    p_row.width, p_row.height, p_row.orientation, p_row.title, p_row.description, p_row.tags,
    p_row.credit, p_row.season, p_row.usage_hint, p_row.colors, p_row.thumb_path,
    p_row.created_at, p_row.classified_at)
  RETURNING * INTO p_row;
  RETURN p_row;
END;
$function$;
