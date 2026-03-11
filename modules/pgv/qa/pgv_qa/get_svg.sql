CREATE OR REPLACE FUNCTION pgv_qa.get_svg()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_svg text;
BEGIN
  v_svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 300">'
    || '<rect x="10" y="10" width="180" height="120" rx="8" fill="#f59e0b" opacity="0.8"/>'
    || '<text x="100" y="75" text-anchor="middle" fill="white" font-size="16" font-weight="bold">Module A</text>'
    || '<rect x="210" y="10" width="180" height="120" rx="8" fill="#3b82f6" opacity="0.8"/>'
    || '<text x="300" y="75" text-anchor="middle" fill="white" font-size="16" font-weight="bold">Module B</text>'
    || '<rect x="110" y="170" width="180" height="120" rx="8" fill="#10b981" opacity="0.8"/>'
    || '<text x="200" y="235" text-anchor="middle" fill="white" font-size="16" font-weight="bold">Module C</text>'
    || '<line x1="100" y1="130" x2="200" y2="170" stroke="#78716c" stroke-width="2" marker-end="url(#arr)"/>'
    || '<line x1="300" y1="130" x2="200" y2="170" stroke="#78716c" stroke-width="2" marker-end="url(#arr)"/>'
    || '<defs><marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto">'
    || '<path d="M0,0 L10,5 L0,10 Z" fill="#78716c"/></marker></defs>'
    || '</svg>';

  RETURN
    '<section><h4>pgv.svg_canvas (defaut)</h4>'
    || '<p>Viewport interactif avec toolbar zoom, pan a la souris, fit automatique.</p>'
    || pgv.svg_canvas(v_svg)
    || '</section>'
    || '<section><h4>Options: hauteur + sans toolbar</h4>'
    || pgv.svg_canvas(v_svg, '{"height": "30vh", "toolbar": false}'::jsonb)
    || '</section>';
END;
$function$;
