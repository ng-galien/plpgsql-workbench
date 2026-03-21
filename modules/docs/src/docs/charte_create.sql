CREATE OR REPLACE FUNCTION docs.charte_create(p_name text, p_description text DEFAULT NULL::text, p_color_bg text DEFAULT '#ffffff'::text, p_color_main text DEFAULT '#1a1a2e'::text, p_color_accent text DEFAULT '#e94560'::text, p_color_text text DEFAULT '#333333'::text, p_color_text_light text DEFAULT '#888888'::text, p_color_border text DEFAULT '#e0e0e0'::text, p_color_extra jsonb DEFAULT '{}'::jsonb, p_font_heading text DEFAULT 'Inter'::text, p_font_body text DEFAULT 'Inter'::text, p_spacing_page text DEFAULT NULL::text, p_spacing_section text DEFAULT NULL::text, p_spacing_gap text DEFAULT NULL::text, p_spacing_card text DEFAULT NULL::text, p_shadow_card text DEFAULT NULL::text, p_shadow_elevated text DEFAULT NULL::text, p_radius_card text DEFAULT NULL::text, p_voice_personality text[] DEFAULT NULL::text[], p_voice_formality text DEFAULT NULL::text, p_voice_do text[] DEFAULT NULL::text[], p_voice_dont text[] DEFAULT NULL::text[], p_voice_vocabulary text[] DEFAULT NULL::text[], p_voice_examples jsonb DEFAULT NULL::jsonb, p_rules jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id text;
BEGIN
  INSERT INTO docs.charte (
    name, description,
    color_bg, color_main, color_accent, color_text, color_text_light, color_border, color_extra,
    font_heading, font_body,
    spacing_page, spacing_section, spacing_gap, spacing_card,
    shadow_card, shadow_elevated, radius_card,
    voice_personality, voice_formality, voice_do, voice_dont, voice_vocabulary, voice_examples,
    rules
  ) VALUES (
    p_name, p_description,
    p_color_bg, p_color_main, p_color_accent, p_color_text, p_color_text_light, p_color_border, p_color_extra,
    p_font_heading, p_font_body,
    p_spacing_page, p_spacing_section, p_spacing_gap, p_spacing_card,
    p_shadow_card, p_shadow_elevated, p_radius_card,
    p_voice_personality, p_voice_formality, p_voice_do, p_voice_dont, p_voice_vocabulary, p_voice_examples,
    p_rules
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$function$;
