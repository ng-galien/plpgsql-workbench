-- pgv schema: shared UI primitives for pgView apps
-- Order matters: atoms first, then molecules that depend on them

-- Atoms ---------------------------------------------------------------

CREATE OR REPLACE FUNCTION pgv.esc(p_text text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT replace(replace(replace(replace(replace(
    coalesce(p_text, ''),
    '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;'), '''', '&#39;');
$function$;

CREATE OR REPLACE FUNCTION pgv.badge(p_text text, p_variant text DEFAULT 'default'::text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT format(
    '<span style="display:inline-block;padding:2px 10px;border-radius:12px;font-size:0.85em;font-weight:500;%s">%s</span>',
    CASE p_variant
      WHEN 'success' THEN 'background:#d4edda;color:#155724'
      WHEN 'danger'  THEN 'background:#f8d7da;color:#721c24'
      WHEN 'warning' THEN 'background:#fff3cd;color:#856404'
      WHEN 'info'    THEN 'background:#d1ecf1;color:#0c5460'
      WHEN 'primary' THEN 'background:#cce5ff;color:#004085'
      ELSE                 'background:#e2e3e5;color:#383d41'
    END,
    p_text
  );
$function$;

CREATE OR REPLACE FUNCTION pgv.money(p_amount numeric)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT to_char(p_amount, 'FM999 999 990D00') || ' EUR';
$function$;

CREATE OR REPLACE FUNCTION pgv.filesize(p_bytes bigint)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE
    WHEN p_bytes IS NULL THEN '-'
    WHEN p_bytes < 1024 THEN p_bytes || ' B'
    WHEN p_bytes < 1048576 THEN round(p_bytes / 1024.0, 1) || ' KB'
    WHEN p_bytes < 1073741824 THEN round(p_bytes / 1048576.0, 1) || ' MB'
    ELSE round(p_bytes / 1073741824.0, 1) || ' GB'
  END;
$function$;

CREATE OR REPLACE FUNCTION pgv.stat(p_label text, p_value text, p_detail text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<article style="text-align:center">'
    || '<small>' || p_label || '</small>'
    || '<p style="font-size:2rem;margin:0.25rem 0;font-weight:600">' || p_value || '</p>'
    || CASE WHEN p_detail IS NOT NULL THEN '<small>' || p_detail || '</small>' ELSE '' END
    || '</article>';
$function$;

-- Molecules -----------------------------------------------------------

CREATE OR REPLACE FUNCTION pgv.dl(VARIADIC p_pairs text[])
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  v_html text := '<dl>';
  i int;
BEGIN
  FOR i IN 1..array_length(p_pairs, 1) BY 2 LOOP
    v_html := v_html || '<dt>' || p_pairs[i] || '</dt><dd>' || coalesce(p_pairs[i+1], '-') || '</dd>';
  END LOOP;
  RETURN v_html || '</dl>';
END;
$function$;

CREATE OR REPLACE FUNCTION pgv.nav(p_brand text, p_items jsonb, p_current text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  v_html text;
  v_item jsonb;
  v_href text;
  v_label text;
BEGIN
  v_html := '<nav class="container-fluid"><ul><li><strong>' || pgv.esc(p_brand) || '</strong></li></ul><ul>';
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_href := v_item->>'href';
    v_label := v_item->>'label';
    IF v_href = p_current THEN
      v_html := v_html || format('<li><a href="%s" hx-get="/rpc/page?p_path=%s" hx-push-url="%s" aria-current="page">%s</a></li>',
        v_href, v_href, v_href, pgv.esc(v_label));
    ELSE
      v_html := v_html || format('<li><a href="%s" hx-get="/rpc/page?p_path=%s" hx-push-url="%s" preload>%s</a></li>',
        v_href, v_href, v_href, pgv.esc(v_label));
    END IF;
  END LOOP;
  v_html := v_html || '</ul></nav>';
  RETURN v_html;
END;
$function$;

CREATE OR REPLACE FUNCTION pgv.card(p_title text, p_body text, p_footer text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<article>'
    || CASE WHEN p_title IS NOT NULL THEN '<header>' || p_title || '</header>' ELSE '' END
    || p_body
    || CASE WHEN p_footer IS NOT NULL THEN '<footer>' || p_footer || '</footer>' ELSE '' END
    || '</article>';
$function$;

CREATE OR REPLACE FUNCTION pgv.grid(VARIADIC p_items text[])
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<div class="grid">' || array_to_string(p_items, '') || '</div>';
$function$;

CREATE OR REPLACE FUNCTION pgv.md_table(p_headers text[], p_rows text[])
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  v_md text;
  v_sep text;
  i int;
BEGIN
  v_md := '| ' || array_to_string(p_headers, ' | ') || E' |\n';
  v_sep := '|';
  FOR i IN 1..array_length(p_headers, 1) LOOP
    v_sep := v_sep || ' --- |';
  END LOOP;
  v_md := v_md || v_sep || E'\n';
  IF p_rows IS NOT NULL AND array_length(p_rows, 1) > 0 THEN
    FOR i IN 1..array_length(p_rows, 1) LOOP
      v_md := v_md || '| ' || array_to_string(p_rows[i:i][1:array_length(p_headers, 1)], ' | ') || E' |\n';
    END LOOP;
  END IF;
  RETURN '<figure><md>' || v_md || '</md></figure>';
END;
$function$;

CREATE OR REPLACE FUNCTION pgv.page(p_title text, p_path text, p_nav jsonb, p_body text)
 RETURNS "text/html"
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  RETURN pgv.nav('pgView', p_nav, p_path)
    || '<main class="container">'
    || '<hgroup><h2>' || pgv.esc(p_title) || '</h2></hgroup>'
    || p_body
    || '</main>';
END;
$function$;

-- Forms ---------------------------------------------------------------

CREATE OR REPLACE FUNCTION pgv.input(p_name text, p_type text, p_label text, p_value text DEFAULT NULL::text, p_required boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<label>' || p_label
    || CASE WHEN p_required THEN ' <sup>*</sup>' ELSE '' END
    || '<input name="' || p_name || '" type="' || p_type || '"'
    || CASE WHEN p_value IS NOT NULL THEN ' value="' || pgv.esc(p_value) || '"' ELSE '' END
    || CASE WHEN p_required THEN ' required' ELSE '' END
    || '></label>';
$function$;

CREATE OR REPLACE FUNCTION pgv.sel(p_name text, p_label text, p_options jsonb, p_selected text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  v_html text;
  v_opt jsonb;
  v_val text;
  v_lbl text;
BEGIN
  v_html := '<label>' || p_label || '<select name="' || p_name || '">';
  v_html := v_html || '<option value="">--</option>';
  FOR v_opt IN SELECT * FROM jsonb_array_elements(p_options)
  LOOP
    IF jsonb_typeof(v_opt) = 'string' THEN
      v_val := v_opt #>> '{}';
      v_lbl := v_val;
    ELSE
      v_val := v_opt->>'value';
      v_lbl := coalesce(v_opt->>'label', v_val);
    END IF;
    v_html := v_html || '<option value="' || pgv.esc(v_val) || '"'
      || CASE WHEN v_val = p_selected THEN ' selected' ELSE '' END
      || '>' || pgv.esc(v_lbl) || '</option>';
  END LOOP;
  RETURN v_html || '</select></label>';
END;
$function$;

CREATE OR REPLACE FUNCTION pgv.textarea(p_name text, p_label text, p_value text DEFAULT NULL::text, p_rows integer DEFAULT 3)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<label>' || p_label
    || '<textarea name="' || p_name || '" rows="' || p_rows || '">'
    || coalesce(pgv.esc(p_value), '')
    || '</textarea></label>';
$function$;

CREATE OR REPLACE FUNCTION pgv.action(p_endpoint text, p_label text, p_target text DEFAULT '#app'::text, p_confirm text DEFAULT NULL::text, p_variant text DEFAULT 'primary'::text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<button hx-post="' || p_endpoint || '" hx-target="' || p_target || '"'
    || CASE WHEN p_confirm IS NOT NULL THEN ' hx-confirm="' || pgv.esc(p_confirm) || '"' ELSE '' END
    || CASE WHEN p_variant = 'danger' THEN ' class="secondary"'
            WHEN p_variant = 'outline' THEN ' class="outline"'
            ELSE '' END
    || '>' || pgv.esc(p_label) || '</button>';
$function$;

-- Grants --------------------------------------------------------------

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pgv TO web_anon;
