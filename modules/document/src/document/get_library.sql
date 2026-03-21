CREATE OR REPLACE FUNCTION document.get_library(p_id text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_lib document.library;
  v_body text;
  v_rows text[];
  r record;
BEGIN
  SELECT * INTO v_lib FROM document.library WHERE id = p_id AND tenant_id = current_setting('app.tenant_id', true);
  IF v_lib IS NULL THEN RETURN pgv.empty('Photothèque introuvable'); END IF;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[pgv.t('document.brand'), '/libraries', pgv.esc(v_lib.name)]);

  IF v_lib.description IS NOT NULL THEN
    v_body := v_body || '<p>' || pgv.esc(v_lib.description) || '</p>';
  END IF;

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.filename, a.title, a.mime_type, a.width, a.height,
           la.role, la.context, la.sort_order
    FROM document.library_asset la
    JOIN asset.asset a ON a.id = la.asset_id
    WHERE la.library_id = p_id
    ORDER BY la.sort_order, a.filename
  LOOP
    v_rows := v_rows || ARRAY[
      r.sort_order::text,
      pgv.esc(r.filename),
      COALESCE(r.title, '—'),
      COALESCE(r.role, '—'),
      COALESCE(r.context, '—'),
      r.mime_type,
      CASE WHEN r.width IS NOT NULL THEN r.width::text || '×' || r.height::text ELSE '—' END
    ];
  END LOOP;

  IF cardinality(v_rows) > 0 THEN
    v_body := v_body || '<h3>Assets</h3>'
      || pgv.md_table(ARRAY['#', 'Fichier', 'Titre', 'Rôle', 'Contexte', 'Type', 'Dimensions'], v_rows, 20);
  ELSE
    v_body := v_body || pgv.empty('Aucun asset dans cette photothèque');
  END IF;

  v_body := v_body || '<p>'
    || pgv.action('post_library_delete', pgv.t('document.btn_delete'), jsonb_build_object('p_name', v_lib.name), 'Supprimer cette photothèque ?', 'danger')
    || '</p>';

  RETURN v_body;
END;
$function$;
