CREATE OR REPLACE FUNCTION asset.get_index(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_total       INT;
  v_to_classify INT;
  v_classified  INT;
  v_status      TEXT;
  v_q           TEXT;
  v_body        TEXT;
  v_rows        TEXT[];
  v_row_count   INT := 0;
  v_status_label TEXT;
  v_dims        TEXT;
  r             RECORD;
BEGIN
  v_status := NULLIF(trim(COALESCE(p_params->>'status', '')), '');
  v_q := NULLIF(trim(COALESCE(p_params->>'q', '')), '');

  -- Stats (unfiltered)
  SELECT count(*)::int INTO v_total FROM asset.asset;
  SELECT count(*)::int INTO v_to_classify FROM asset.asset WHERE status = 'to_classify';
  SELECT count(*)::int INTO v_classified FROM asset.asset WHERE status = 'classified';

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('asset.stat_total'), v_total::text),
    pgv.stat(pgv.t('asset.stat_to_classify'), v_to_classify::text),
    pgv.stat(pgv.t('asset.stat_classified'), v_classified::text)
  ]);

  -- Filters
  v_body := v_body
    || '<form>'
    || '<div class="grid">'
    || pgv.sel('status', pgv.t('asset.field_status'), jsonb_build_array(
         jsonb_build_object('label', pgv.t('asset.filter_all'), 'value', ''),
         jsonb_build_object('label', pgv.t('asset.status_to_classify'), 'value', 'to_classify'),
         jsonb_build_object('label', pgv.t('asset.status_classified'), 'value', 'classified'),
         jsonb_build_object('label', pgv.t('asset.status_archived'), 'value', 'archived')
       ), COALESCE(v_status, ''))
    || pgv.input('q', 'search', pgv.t('asset.field_search'), v_q)
    || '</div>'
    || '<button type="submit" class="secondary">' || pgv.t('asset.btn_filter') || '</button>'
    || '</form>';

  IF v_total = 0 THEN
    v_body := v_body || pgv.empty(pgv.t('asset.empty_no_asset'), pgv.t('asset.empty_first_asset'));
  ELSE
    -- Table rows
    v_rows := ARRAY[
      '| | ' || pgv.t('asset.col_title') || ' | ' || pgv.t('asset.col_filename')
        || ' | ' || pgv.t('asset.col_mime') || ' | ' || pgv.t('asset.col_tags')
        || ' | ' || pgv.t('asset.col_status') || ' | ' || pgv.t('asset.field_dimensions') || ' |',
      '|---|---|---|---|---|---|---|'
    ];

    FOR r IN
      SELECT a.id, a.path, a.thumb_path, a.filename, a.title, a.status, a.tags,
             a.width, a.height, a.mime_type
      FROM asset.asset a
      WHERE (v_status IS NULL OR a.status = v_status)
        AND (v_q IS NULL OR a.search_vec @@ plainto_tsquery('pgv_search', v_q))
      ORDER BY a.created_at DESC
    LOOP
      v_status_label := CASE r.status
        WHEN 'classified' THEN pgv.badge(pgv.t('asset.status_classified'), 'success')
        WHEN 'to_classify' THEN pgv.badge(pgv.t('asset.status_to_classify'), 'warning')
        ELSE pgv.badge(r.status, 'default')
      END;

      v_dims := CASE WHEN r.width IS NOT NULL
        THEN r.width::text || '×' || r.height::text
        ELSE '—' END;

      v_rows := v_rows || (
        '| <img src="' || COALESCE(r.thumb_path, r.path) || '" style="height:40px;width:60px;object-fit:cover;border-radius:4px">'
        || ' | [' || pgv.esc(COALESCE(r.title, r.filename)) || '](/asset/asset?p_id=' || r.id || ')'
        || ' | ' || pgv.esc(r.filename)
        || ' | ' || r.mime_type
        || ' | ' || COALESCE(array_to_string(r.tags[1:4], ', '), '')
        || ' | ' || v_status_label
        || ' | ' || v_dims
        || ' |'
      );
      v_row_count := v_row_count + 1;
    END LOOP;

    IF v_row_count = 0 THEN
      v_body := v_body || pgv.empty(pgv.t('asset.empty_no_results'));
    ELSE
      v_body := v_body || '<md data-page="20">' || array_to_string(v_rows, E'\n') || '</md>';
    END IF;
  END IF;

  RETURN v_body;
END;
$function$;
