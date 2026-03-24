CREATE OR REPLACE FUNCTION asset.nav_items()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_array(
    jsonb_build_object('href', '/', 'label', pgv.t('asset.nav_assets'), 'icon', 'image', 'entity', 'asset'),
    jsonb_build_object('href', '/upload', 'label', pgv.t('asset.nav_upload'), 'icon', 'upload')
  );
END;
$function$;
