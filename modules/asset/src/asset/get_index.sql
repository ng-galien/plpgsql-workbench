CREATE OR REPLACE FUNCTION asset.get_index(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_total       INT;
  v_to_classify INT;
  v_classified  INT;
  v_body        TEXT;
BEGIN
  -- Stats
  SELECT count(*)::int INTO v_total FROM asset.asset;
  SELECT count(*)::int INTO v_to_classify FROM asset.asset WHERE status = 'to_classify';
  SELECT count(*)::int INTO v_classified FROM asset.asset WHERE status = 'classified';

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('asset.stat_total'), v_total::text),
    pgv.stat(pgv.t('asset.stat_to_classify'), v_to_classify::text),
    pgv.stat(pgv.t('asset.stat_classified'), v_classified::text)
  ]);

  IF v_total = 0 THEN
    v_body := v_body || pgv.empty(pgv.t('asset.empty_no_asset'), pgv.t('asset.empty_first_asset'));
  ELSE
    v_body := v_body || pgv.table(jsonb_build_object(
      'rpc',     'data_assets',
      'schema',  'asset',
      'filters', jsonb_build_array(
        jsonb_build_object('name','p_status','type','select','label', pgv.t('asset.field_status'),
          'options', jsonb_build_array(
            jsonb_build_array('', pgv.t('asset.filter_all')),
            jsonb_build_array('to_classify', pgv.t('asset.status_to_classify')),
            jsonb_build_array('classified', pgv.t('asset.status_classified')),
            jsonb_build_array('archived', pgv.t('asset.status_archived')))),
        jsonb_build_object('name','q','type','search','label', pgv.t('asset.field_search'))
      ),
      'cols', jsonb_build_array(
        jsonb_build_object('key','id','label','#','hidden',true),
        jsonb_build_object('key','filename','label', pgv.t('asset.col_filename')),
        jsonb_build_object('key','title','label', pgv.t('asset.col_title')),
        jsonb_build_object('key','mime','label', pgv.t('asset.col_mime')),
        jsonb_build_object('key','status','label', pgv.t('asset.col_status'),'class','pgv-col-badge'),
        jsonb_build_object('key','tags','label', pgv.t('asset.col_tags')),
        jsonb_build_object('key','created','label', pgv.t('asset.col_created'))
      ),
      'page_size', 20
    ));
  END IF;

  RETURN v_body;
END;
$function$;
