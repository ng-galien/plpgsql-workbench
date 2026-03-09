CREATE OR REPLACE FUNCTION shop.pgv_badge(p_text text, p_variant text DEFAULT 'default'::text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT format(
    '<span style="display:inline-block;padding:2px 10px;border-radius:12px;font-size:0.85em;font-weight:500;%s">%s</span>',
    CASE p_variant
      WHEN 'success'  THEN 'background:#d4edda;color:#155724'
      WHEN 'danger'   THEN 'background:#f8d7da;color:#721c24'
      WHEN 'warning'  THEN 'background:#fff3cd;color:#856404'
      WHEN 'info'     THEN 'background:#cce5ff;color:#004085'
      WHEN 'platinum' THEN 'background:linear-gradient(135deg,#e5e4e2,#b8b8b8);color:#333'
      WHEN 'gold'     THEN 'background:linear-gradient(135deg,#ffd700,#daa520);color:#333'
      WHEN 'silver'   THEN 'background:linear-gradient(135deg,#c0c0c0,#a0a0a0);color:#333'
      WHEN 'bronze'   THEN 'background:linear-gradient(135deg,#cd7f32,#a0522d);color:#fff'
      ELSE                  'background:#e2e3e5;color:#383d41'
    END,
    p_text
  );
$function$;
