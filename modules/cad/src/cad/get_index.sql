CREATE OR REPLACE FUNCTION cad.get_index()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_drawings text;
BEGIN
  SELECT string_agg(
    pgv.card(
      d.name,
      format('%s × %s %s — échelle 1:%s', d.width, d.height, d.unit, d.scale),
      format('<a href="%s">%s</a>',
        pgv.call_ref('get_drawing', jsonb_build_object('p_id', d.id)),
        pgv.t('cad.btn_ouvrir'))
    ), E'\n' ORDER BY d.updated_at DESC
  ) INTO v_drawings
  FROM cad.drawing d;

  v_body := COALESCE(v_drawings, '<p>' || pgv.t('cad.empty_no_drawing') || '</p>');

  v_body := v_body || pgv.form_dialog('dlg-new-drawing',
    pgv.t('cad.btn_nouveau_dessin'),
    pgv.input('name', 'text', pgv.t('cad.field_name')),
    'drawing_add');

  RETURN v_body;
END;
$function$;
