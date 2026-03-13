CREATE OR REPLACE FUNCTION ops.get_tools()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_rows text[];
  v_total int;
  v_packs int;
  v_total_calls int;
  v_total_blocked int;
  r record;
BEGIN
  -- Stats globales
  SELECT count(*)::int INTO v_total FROM workbench.toolbox_tool;
  SELECT count(DISTINCT
    CASE
      WHEN tool_name LIKE 'pg\_%' ESCAPE '\' THEN 'plpgsql'
      WHEN tool_name LIKE 'fs\_%' ESCAPE '\' THEN 'docstore'
      WHEN tool_name LIKE 'gmail\_%' ESCAPE '\' THEN 'google'
      WHEN tool_name LIKE 'doc\_%' ESCAPE '\' THEN 'docman'
      WHEN tool_name LIKE 'ws\_%' ESCAPE '\' THEN 'plpgsql'
      ELSE 'other'
    END
  )::int INTO v_packs FROM workbench.toolbox_tool;

  SELECT count(*)::int, count(*) FILTER (WHERE NOT allowed)::int
    INTO v_total_calls, v_total_blocked
    FROM workbench.hook_log;

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat('Tools', v_total::text),
    pgv.stat('Packs', v_packs::text),
    pgv.stat('Appels traces', v_total_calls::text, 'hook_log'),
    pgv.stat('Bloques', v_total_blocked::text, 'par hooks')
  ]);

  -- Table des tools avec stats
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT t.tool_name,
           CASE
             WHEN t.tool_name LIKE 'pg\_%' ESCAPE '\' THEN 'plpgsql'
             WHEN t.tool_name LIKE 'fs\_%' ESCAPE '\' THEN 'docstore'
             WHEN t.tool_name LIKE 'gmail\_%' ESCAPE '\' THEN 'google'
             WHEN t.tool_name LIKE 'doc\_%' ESCAPE '\' THEN 'docman'
             WHEN t.tool_name LIKE 'ws\_%' ESCAPE '\' THEN 'plpgsql'
             ELSE 'other'
           END AS pack,
           COALESCE(h.call_count, 0)::int AS calls,
           COALESCE(h.blocked, 0)::int AS blocked
      FROM workbench.toolbox_tool t
      LEFT JOIN (
        SELECT replace(tool, 'mcp__plpgsql-workbench__', '') AS tool_short,
               count(*)::int AS call_count,
               count(*) FILTER (WHERE NOT allowed)::int AS blocked
          FROM workbench.hook_log
         GROUP BY tool_short
      ) h ON h.tool_short = t.tool_name
     ORDER BY
       CASE
         WHEN t.tool_name LIKE 'pg\_%' ESCAPE '\' THEN 1
         WHEN t.tool_name LIKE 'ws\_%' ESCAPE '\' THEN 1
         WHEN t.tool_name LIKE 'fs\_%' ESCAPE '\' THEN 2
         WHEN t.tool_name LIKE 'gmail\_%' ESCAPE '\' THEN 3
         WHEN t.tool_name LIKE 'doc\_%' ESCAPE '\' THEN 4
         ELSE 5
       END,
       t.tool_name
  LOOP
    v_rows := v_rows || ARRAY[
      '<a href="/ops/tool?p_name=' || pgv.esc(r.tool_name) || '">' || pgv.esc(r.tool_name) || '</a>',
      pgv.badge(r.pack, CASE r.pack
        WHEN 'plpgsql' THEN 'success'
        WHEN 'docstore' THEN 'info'
        WHEN 'google' THEN 'warning'
        WHEN 'docman' THEN 'default'
        ELSE 'default'
      END),
      r.calls::text,
      CASE WHEN r.blocked > 0
        THEN pgv.badge(r.blocked::text, 'danger')
        ELSE '0'
      END
    ];
  END LOOP;

  v_body := v_body || pgv.md_table(
    ARRAY['Tool', 'Pack', 'Appels', 'Bloques'],
    v_rows
  );

  RETURN v_body;
END;
$function$;
