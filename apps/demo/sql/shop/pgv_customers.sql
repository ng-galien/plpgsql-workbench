CREATE OR REPLACE FUNCTION shop.pgv_customers()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
  v_md text;
  r record;
BEGIN
  v_html := '<main class="container">';
  v_html := v_html || '<hgroup><h2>Customers</h2><p>All registered customers</p></hgroup>';

  v_md := E'| Name | Email | Tier | Since |\n| --- | --- | --- | --- |\n';
  FOR r IN
    SELECT c.*, shop.customer_tier(c.id) AS tier,
           to_char(c.created_at, 'YYYY-MM-DD') AS dt
    FROM shop.customers c ORDER BY c.name
  LOOP
    v_md := v_md || format(E'| <a href="/customers/%s">%s</a> | %s | %s | %s |\n',
      r.id, shop.esc(r.name), shop.esc(r.email),
      shop.pgv_tier(r.tier), r.dt);
  END LOOP;

  v_html := v_html || '<figure><md>' || v_md || '</md></figure></main>';
  RETURN v_html;
END;
$function$;
