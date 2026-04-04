CREATE OR REPLACE FUNCTION asset.classify(p_id uuid, p_title text, p_description text DEFAULT NULL::text, p_tags text[] DEFAULT '{}'::text[], p_width integer DEFAULT NULL::integer, p_height integer DEFAULT NULL::integer, p_orientation text DEFAULT NULL::text, p_season text DEFAULT NULL::text, p_credit text DEFAULT NULL::text, p_usage_hint text DEFAULT NULL::text, p_colors text[] DEFAULT '{}'::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_found BOOLEAN;
BEGIN
  IF p_title IS NULL OR trim(p_title) = '' THEN
    RAISE EXCEPTION '%', pgv.t('asset.err_title_required');
  END IF;

  UPDATE asset.asset SET
    title         = trim(p_title),
    description   = NULLIF(trim(COALESCE(p_description,'')), ''),
    tags          = COALESCE(p_tags, '{}'),
    width         = p_width,
    height        = p_height,
    orientation   = p_orientation,
    season        = p_season,
    credit        = NULLIF(trim(COALESCE(p_credit,'')), ''),
    usage_hint    = NULLIF(trim(COALESCE(p_usage_hint,'')), ''),
    colors        = COALESCE(p_colors, '{}'),
    status        = 'classified',
    classified_at = now()
  WHERE id = p_id
  RETURNING TRUE INTO v_found;

  IF NOT v_found THEN
    RAISE EXCEPTION '%', pgv.t('asset.err_not_found');
  END IF;

  RETURN jsonb_build_object('id', p_id, 'status', 'classified');
END;
$function$;
