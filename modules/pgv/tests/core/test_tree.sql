CREATE OR REPLACE FUNCTION pgv_ut.test_tree()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  -- Leaf node
  v_html := pgv.tree('[{"label": "Feuille"}]'::jsonb);
  RETURN NEXT ok(v_html LIKE '%<ul class="pgv-tree">%', 'tree has pgv-tree class');
  RETURN NEXT ok(v_html LIKE '%<li>Feuille</li>%', 'leaf node renders text');

  -- Link node
  v_html := pgv.tree('[{"label": "Lien", "href": "/page"}]'::jsonb);
  RETURN NEXT ok(v_html LIKE '%<a href="/page">Lien</a>%', 'link node has href');

  -- Branch node (closed by default)
  v_html := pgv.tree('[{"label": "Parent", "children": [{"label": "Enfant"}]}]'::jsonb);
  RETURN NEXT ok(v_html LIKE '%<details>%', 'branch has details tag');
  RETURN NEXT ok(v_html LIKE '%<summary>Parent</summary>%', 'branch has summary');
  RETURN NEXT ok(v_html NOT LIKE '%<details open%', 'branch closed by default');

  -- Branch node (open)
  v_html := pgv.tree('[{"label": "Ouvert", "open": true, "children": [{"label": "Visible"}]}]'::jsonb);
  RETURN NEXT ok(v_html LIKE '%<details open%', 'open branch has details open');

  -- Global open
  v_html := pgv.tree('[{"label": "A", "children": [{"label": "B"}]}]'::jsonb, true);
  RETURN NEXT ok(v_html LIKE '%<details open%', 'p_open=true opens all branches');

  -- Nested depth (no pgv-tree class on inner ul)
  v_html := pgv.tree('[{"label": "L1", "children": [{"label": "L2", "children": [{"label": "L3"}]}]}]'::jsonb);
  RETURN NEXT ok(v_html LIKE '%<ul class="pgv-tree"><li><details><summary>L1</summary><ul><li>%',
    'inner ul has no pgv-tree class');

  -- XSS escape
  v_html := pgv.tree('[{"label": "<script>alert(1)</script>"}]'::jsonb);
  RETURN NEXT ok(v_html NOT LIKE '%<script>%', 'label is HTML-escaped');

  -- Icon (raw HTML, not escaped)
  v_html := pgv.tree('[{"label": "Fichier", "icon": "📄"}]'::jsonb);
  RETURN NEXT ok(v_html LIKE '%<span class="pgv-tree-icon">%', 'icon has pgv-tree-icon class');
  RETURN NEXT ok(v_html LIKE '%pgv-tree-icon">📄</span> Fichier%', 'icon before label');

  v_html := pgv.tree('[{"label": "Pièce", "icon": "<span class=\"cad-swatch\" data-color=\"#c8956c\"></span>"}]'::jsonb);
  RETURN NEXT ok(v_html LIKE '%<span class="cad-swatch"%', 'icon accepts raw HTML');

  -- Badge
  v_html := pgv.tree('[{"label": "Dossier", "badge": "3"}]'::jsonb);
  RETURN NEXT ok(v_html LIKE '%pgv-badge%', 'badge renders pgv-badge');
  RETURN NEXT ok(v_html LIKE '%Dossier%pgv-badge%', 'badge after label');

  -- Action (object -> pgv.action)
  v_html := pgv.tree('[{"label": "Item", "action": {"rpc": "delete_item", "label": "Suppr", "params": {"id": 1}, "confirm": "Sûr?"}}]'::jsonb);
  RETURN NEXT ok(v_html LIKE '%data-rpc="delete_item"%', 'action object has data-rpc');
  RETURN NEXT ok(v_html LIKE '%data-confirm="Sûr?"%', 'action object has data-confirm');
  RETURN NEXT ok(v_html LIKE '%data-params%', 'action object has data-params');

  -- Action (string -> raw HTML)
  v_html := pgv.tree('[{"label": "Vis", "action": "<button class=\"cad-eye\" @click.stop=\"toggle(7)\">◉</button>"}]'::jsonb);
  RETURN NEXT ok(v_html LIKE '%<button class="cad-eye"%', 'action string renders raw HTML');
  RETURN NEXT ok(v_html LIKE '%@click.stop="toggle(7)"%', 'action string preserves Alpine attrs');

  -- Attrs on li
  v_html := pgv.tree('[{"label": "Pièce", "attrs": "data-id=\"42\" class=\"selected\""}]'::jsonb);
  RETURN NEXT ok(v_html LIKE '%<li data-id="42" class="selected">%', 'attrs on li');

  -- Root attrs
  v_html := pgv.tree('[{"label": "A"}]'::jsonb, false, 0, 'id="my-tree" data-sync="viewer"');
  RETURN NEXT ok(v_html LIKE '%<ul class="pgv-tree" id="my-tree" data-sync="viewer">%', 'root_attrs on ul');

  -- Icon on branch summary
  v_html := pgv.tree('[{"label": "Groupe", "icon": "📁", "children": [{"label": "Sub"}]}]'::jsonb);
  RETURN NEXT ok(v_html LIKE '%<summary><span class="pgv-tree-icon">📁</span> Groupe</summary>%', 'icon in branch summary');
END;
$function$;
