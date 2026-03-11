CREATE OR REPLACE FUNCTION cad.get_index()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_body text;
  v_drawings text;
BEGIN
  SELECT string_agg(
    pgv.card(
      d.name,
      format('%s × %s %s — échelle 1:%s', d.width, d.height, d.unit, d.scale),
      format('<a href="%s">Ouvrir</a>',
        pgv.call_ref('get_drawing', jsonb_build_object('p_id', d.id)))
    ), E'\n' ORDER BY d.updated_at DESC
  ) INTO v_drawings
  FROM cad.drawing d;

  v_body := COALESCE(v_drawings, '<p>Aucun dessin. Créez-en un ci-dessous.</p>');

  v_body := v_body ||
    '<form data-rpc="drawing_add">'
    '<fieldset role="group">'
    || pgv.input('name', 'text', 'Nom du dessin')
    || '<button type="submit">Nouveau dessin</button>'
    '</fieldset>'
    '</form>';

  RETURN v_body;
END;
$function$;
