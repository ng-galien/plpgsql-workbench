CREATE OR REPLACE FUNCTION docs.charte_read(p_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_c docs.charte;
  v_css text;
  v_token text;
BEGIN
  SELECT * INTO v_c FROM docs.charte
  WHERE name = p_name AND tenant_id = current_setting('app.tenant_id', true);
  IF v_c IS NULL THEN RETURN NULL; END IF;

  v_css := docs.charte_tokens_to_css(v_c.id);

  -- context_token: md5 of charte id + all color tokens (invalidates on any change)
  v_token := md5('charte:' || v_c.id || '|' || v_c.color_bg || v_c.color_main || v_c.color_accent
    || v_c.color_text || v_c.color_text_light || v_c.color_border
    || COALESCE(v_c.color_extra::text, '') || v_c.font_heading || v_c.font_body);

  RETURN jsonb_build_object(
    'id', v_c.id,
    'name', v_c.name,
    'description', v_c.description,
    'css', v_css,
    'colors', jsonb_build_object(
      'bg', v_c.color_bg, 'main', v_c.color_main, 'accent', v_c.color_accent,
      'text', v_c.color_text, 'text_light', v_c.color_text_light, 'border', v_c.color_border,
      'extra', v_c.color_extra
    ),
    'fonts', jsonb_build_object('heading', v_c.font_heading, 'body', v_c.font_body),
    'spacing', jsonb_build_object(
      'page', v_c.spacing_page, 'section', v_c.spacing_section,
      'gap', v_c.spacing_gap, 'card', v_c.spacing_card
    ),
    'shadow', jsonb_build_object('card', v_c.shadow_card, 'elevated', v_c.shadow_elevated),
    'radius', jsonb_build_object('card', v_c.radius_card),
    'voice', jsonb_build_object(
      'personality', to_jsonb(v_c.voice_personality),
      'formality', v_c.voice_formality,
      'do', to_jsonb(v_c.voice_do),
      'dont', to_jsonb(v_c.voice_dont),
      'vocabulary', to_jsonb(v_c.voice_vocabulary),
      'examples', v_c.voice_examples
    ),
    'rules', v_c.rules,
    'context_token', v_token
  );
END;
$function$;
