CREATE OR REPLACE FUNCTION asset.get_asset(p_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  a       RECORD;
  v_body  TEXT;
  v_status_variant TEXT;
  v_tags  TEXT;
  v_colors TEXT;
  v_dl    TEXT[];
BEGIN
  SELECT * INTO a FROM asset.asset WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION '%', pgv.t('asset.err_not_found');
  END IF;

  v_status_variant := CASE a.status
    WHEN 'classified' THEN 'success'
    WHEN 'to_classify' THEN 'warning'
    ELSE 'default'
  END;

  -- Breadcrumb
  v_body := pgv.breadcrumb(VARIADIC ARRAY[
    pgv.t('asset.nav_assets'), '/',
    COALESCE(a.title, a.filename)
  ]);

  -- Image
  v_body := v_body
    || '<img src="' || pgv.esc(a.path) || '" style="max-width:100%;border-radius:8px" loading="lazy">';

  -- Tags as badges
  IF cardinality(a.tags) > 0 THEN
    v_tags := array_to_string(
      ARRAY(SELECT pgv.badge(t, 'default') FROM unnest(a.tags) AS t),
      ' ');
  ELSE
    v_tags := '-';
  END IF;

  -- Colors as inline swatches
  IF cardinality(a.colors) > 0 THEN
    v_colors := array_to_string(
      ARRAY(SELECT '<span style="display:inline-block;width:24px;height:24px;border-radius:4px;background:' || c || ';margin-right:4px;vertical-align:middle" title="' || c || '"></span>' FROM unnest(a.colors) AS c),
      '');
  ELSE
    v_colors := '-';
  END IF;

  -- Metadata DL
  v_dl := ARRAY[
    pgv.t('asset.field_title'), COALESCE(pgv.esc(a.title), '-'),
    pgv.t('asset.field_description'), COALESCE(pgv.esc(a.description), '-'),
    pgv.t('asset.field_filename'), pgv.esc(a.filename),
    pgv.t('asset.field_mime'), a.mime_type,
    pgv.t('asset.field_dimensions'), CASE WHEN a.width IS NOT NULL THEN a.width::text || ' × ' || a.height::text ELSE '-' END,
    pgv.t('asset.field_orientation'), COALESCE(a.orientation, '-'),
    pgv.t('asset.field_status'), pgv.badge(a.status, v_status_variant),
    pgv.t('asset.field_saison'), COALESCE(a.saison, '-'),
    pgv.t('asset.field_credit'), COALESCE(pgv.esc(a.credit), '-'),
    pgv.t('asset.field_usage_hint'), COALESCE(pgv.esc(a.usage_hint), '-'),
    pgv.t('asset.field_tags'), v_tags,
    pgv.t('asset.field_colors'), v_colors,
    pgv.t('asset.field_created'), to_char(a.created_at, 'DD/MM/YYYY HH24:MI'),
    pgv.t('asset.field_classified'), CASE WHEN a.classified_at IS NOT NULL THEN to_char(a.classified_at, 'DD/MM/YYYY HH24:MI') ELSE '-' END
  ];
  v_body := v_body || pgv.dl(VARIADIC v_dl);

  -- Actions
  v_body := v_body || '<p>';
  IF a.status = 'to_classify' THEN
    v_body := v_body || pgv.badge(pgv.t('asset.btn_classify'), 'warning') || ' ';
  END IF;
  v_body := v_body || pgv.action(
    pgv.t('asset.btn_delete'), 'post_asset_delete',
    jsonb_build_object('p_id', a.id),
    'secondary', pgv.t('asset.confirm_delete')
  );
  v_body := v_body || '</p>';

  RETURN v_body;
END;
$function$;
