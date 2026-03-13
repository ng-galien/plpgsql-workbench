CREATE OR REPLACE FUNCTION pgv.form_dialog(p_id text, p_title text, p_body text, p_rpc text, p_label text DEFAULT NULL::text, p_variant text DEFAULT NULL::text, p_src text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  v_trigger text;
  v_dialog text;
  v_btn_class text;
BEGIN
  -- Trigger button
  v_btn_class := CASE
    WHEN p_variant = 'outline' THEN ' class="outline"'
    WHEN p_variant = 'secondary' THEN ' class="secondary"'
    WHEN p_variant = 'contrast' THEN ' class="contrast"'
    ELSE ''
  END;

  v_trigger := '<button data-form-dialog="' || pgv.esc(p_id) || '"'
    || CASE WHEN p_src IS NOT NULL THEN ' data-src="' || pgv.esc(p_src) || '"' ELSE '' END
    || v_btn_class
    || '>' || pgv.esc(coalesce(p_label, p_title)) || '</button>';

  -- Dialog element
  v_dialog := '<dialog id="' || pgv.esc(p_id) || '" class="pgv-form-dialog">'
    || '<article class="pgv-form-dialog-article">'
    || '<header class="pgv-form-dialog-header">'
    || '<strong>' || pgv.esc(p_title) || '</strong>'
    || '<button class="pgv-form-dialog-close" onclick="this.closest(''dialog'').close()">&times;</button>'
    || '</header>'
    || '<form data-rpc="' || pgv.esc(p_rpc) || '" data-dialog-form>'
    || '<div class="pgv-form-dialog-body">' || p_body || '</div>'
    || '<footer class="pgv-form-dialog-footer">'
    || '<button type="button" class="secondary" onclick="this.closest(''dialog'').close()">'
    || pgv.t('cancel') || '</button>'
    || '<button type="submit">' || pgv.t('send') || '</button>'
    || '</footer>'
    || '</form>'
    || '</article>'
    || '</dialog>';

  RETURN v_trigger || v_dialog;
END;
$function$;
