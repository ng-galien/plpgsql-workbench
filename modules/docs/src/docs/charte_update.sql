CREATE OR REPLACE FUNCTION docs.charte_update(p_data docs.charte)
 RETURNS docs.charte
 LANGUAGE plpgsql
 SET "api.expose" TO 'mcp'
AS $function$
BEGIN
  IF p_data.name IS NOT NULL AND p_data.name != '' THEN
    p_data.slug := pgv.slugify(p_data.name);
  END IF;

  UPDATE docs.charte SET
    name = COALESCE(NULLIF(p_data.name, ''), name),
    slug = COALESCE(NULLIF(p_data.slug, ''), slug),
    description = COALESCE(p_data.description, description),
    color_bg = COALESCE(NULLIF(p_data.color_bg, ''), color_bg),
    color_main = COALESCE(NULLIF(p_data.color_main, ''), color_main),
    color_accent = COALESCE(NULLIF(p_data.color_accent, ''), color_accent),
    color_text = COALESCE(NULLIF(p_data.color_text, ''), color_text),
    color_text_light = COALESCE(NULLIF(p_data.color_text_light, ''), color_text_light),
    color_border = COALESCE(NULLIF(p_data.color_border, ''), color_border),
    color_extra = COALESCE(p_data.color_extra, color_extra),
    font_heading = COALESCE(NULLIF(p_data.font_heading, ''), font_heading),
    font_body = COALESCE(NULLIF(p_data.font_body, ''), font_body),
    spacing_page = COALESCE(p_data.spacing_page, spacing_page),
    spacing_section = COALESCE(p_data.spacing_section, spacing_section),
    spacing_gap = COALESCE(p_data.spacing_gap, spacing_gap),
    spacing_card = COALESCE(p_data.spacing_card, spacing_card),
    shadow_card = COALESCE(p_data.shadow_card, shadow_card),
    shadow_elevated = COALESCE(p_data.shadow_elevated, shadow_elevated),
    radius_card = COALESCE(p_data.radius_card, radius_card),
    voice_personality = COALESCE(p_data.voice_personality, voice_personality),
    voice_formality = COALESCE(p_data.voice_formality, voice_formality),
    voice_do = COALESCE(p_data.voice_do, voice_do),
    voice_dont = COALESCE(p_data.voice_dont, voice_dont),
    voice_vocabulary = COALESCE(p_data.voice_vocabulary, voice_vocabulary),
    voice_examples = COALESCE(p_data.voice_examples, voice_examples),
    rules = COALESCE(p_data.rules, rules),
    updated_at = now()
  WHERE (slug = p_data.slug OR id = p_data.id) AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_data;
  RETURN p_data;
END;
$function$;
