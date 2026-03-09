CREATE OR REPLACE FUNCTION shop.pgv_graph()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
  v_mermaid text;
  r record;
BEGIN
  v_mermaid := 'graph LR' || chr(10);

  -- Router
  v_mermaid := v_mermaid || '  subgraph s_router["Router"]' || chr(10);
  v_mermaid := v_mermaid || '    fn_page["page"]' || chr(10);
  v_mermaid := v_mermaid || '  end' || chr(10);

  -- Pages
  v_mermaid := v_mermaid || '  subgraph s_pages["Pages"]' || chr(10);
  FOR r IN
    SELECT p.proname FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'shop' AND p.proname LIKE 'pgv_%'
      AND p.proname NOT IN ('pgv_nav','pgv_money','pgv_badge','pgv_status','pgv_tier','pgv_graph')
      AND p.prolang = (SELECT oid FROM pg_language WHERE lanname = 'plpgsql')
    ORDER BY p.proname
  LOOP
    v_mermaid := v_mermaid || '    fn_' || r.proname || '["' || r.proname || '"]' || chr(10);
  END LOOP;
  v_mermaid := v_mermaid || '  end' || chr(10);

  -- Business
  v_mermaid := v_mermaid || '  subgraph s_business["Business"]' || chr(10);
  FOR r IN
    SELECT p.proname FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'shop' AND p.proname NOT LIKE 'pgv_%'
      AND p.proname NOT IN ('page','esc','path_segment')
      AND p.prolang = (SELECT oid FROM pg_language WHERE lanname = 'plpgsql')
    ORDER BY p.proname
  LOOP
    v_mermaid := v_mermaid || '    fn_' || r.proname || '["' || r.proname || '"]' || chr(10);
  END LOOP;
  v_mermaid := v_mermaid || '  end' || chr(10);

  -- Tables
  v_mermaid := v_mermaid || '  subgraph s_tables["Tables"]' || chr(10);
  FOR r IN
    SELECT tablename FROM pg_tables WHERE schemaname = 'shop' ORDER BY tablename
  LOOP
    v_mermaid := v_mermaid || '    tbl_' || r.tablename || '[("' || r.tablename || '")]' || chr(10);
  END LOOP;
  v_mermaid := v_mermaid || '  end' || chr(10);

  -- Edges
  FOR r IN
    SELECT p.proname AS source, d.type AS dep_type, d.name AS target
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'shop'
    CROSS JOIN LATERAL plpgsql_show_dependency_tb(p.oid) d
    WHERE p.prolang = (SELECT oid FROM pg_language WHERE lanname = 'plpgsql')
      AND d.schema = 'shop'
      AND d.name NOT IN ('esc','path_segment','pgv_money','pgv_badge','pgv_status','pgv_tier','pgv_nav','pgv_graph')
      AND p.proname NOT IN ('pgv_graph')
    ORDER BY p.proname, d.type, d.name
  LOOP
    IF r.dep_type = 'FUNCTION' THEN
      v_mermaid := v_mermaid || '  fn_' || r.source || ' --> fn_' || r.target || chr(10);
    ELSIF r.dep_type = 'RELATION' AND r.source NOT LIKE 'pgv_%' THEN
      v_mermaid := v_mermaid || '  fn_' || r.source || ' -.-> tbl_' || r.target || chr(10);
    END IF;
  END LOOP;

  v_html := '<main class="container">';
  v_html := v_html || '<hgroup><h2>Dependency Graph</h2><p>Auto-generated from plpgsql_check</p></hgroup>';
  v_html := v_html || '<article style="overflow-x:auto"><pre class="mermaid">' || chr(10) || v_mermaid || '</pre></article>';
  v_html := v_html || '<script>
var s = document.createElement("script");
s.src = "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js";
s.onload = function() {
  mermaid.initialize({ startOnLoad: false, theme: "default" });
  mermaid.run({ querySelector: ".mermaid" });
};
document.head.appendChild(s);
</script>';
  v_html := v_html || '</main>';
  RETURN v_html;
END;
$function$;
