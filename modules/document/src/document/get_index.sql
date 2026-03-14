CREATE OR REPLACE FUNCTION document.get_index(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_total_tpl  int;
  v_total_doc  int;
  v_total_cvs  int;
  v_draft      int;
  v_body       text;
  v_cards      text[];
  v_svg        text;
  v_elem_cnt   int;
  v_href       text;
  r            record;
BEGIN
  SELECT count(*)::int INTO v_total_tpl FROM document.template WHERE tenant_id = current_setting('app.tenant_id', true);
  SELECT count(*)::int INTO v_total_doc FROM document.document WHERE tenant_id = current_setting('app.tenant_id', true);
  SELECT count(*)::int INTO v_total_cvs FROM document.canvas WHERE tenant_id = current_setting('app.tenant_id', true);
  SELECT count(*)::int INTO v_draft FROM document.document WHERE tenant_id = current_setting('app.tenant_id', true) AND status = 'draft';

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('document.stat_canvases'), v_total_cvs::text),
    pgv.stat(pgv.t('document.stat_templates'), v_total_tpl::text),
    pgv.stat(pgv.t('document.stat_documents'), v_total_doc::text),
    pgv.stat(pgv.t('document.stat_draft'), v_draft::text)
  ]);

  -- Canvas section: grid of clickable cards with SVG miniature
  v_body := v_body || '<h3>' || pgv.t('document.title_canvases') || '</h3>';
  IF v_total_cvs = 0 THEN
    v_body := v_body || pgv.empty(pgv.t('document.empty_no_canvas'), pgv.t('document.empty_first_canvas'));
  ELSE
    v_cards := ARRAY[]::text[];
    FOR r IN
      SELECT c.id, c.name, c.format, c.orientation, c.category
      FROM document.canvas c
      WHERE c.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY c.updated_at DESC
    LOOP
      v_svg := document.canvas_render_svg_mini(r.id);
      SELECT count(*)::int INTO v_elem_cnt FROM document.element WHERE canvas_id = r.id;
      v_href := pgv.call_ref('get_editor', jsonb_build_object('p_id', r.id));

      v_cards := v_cards || (
        '<a href="' || v_href || '">'
        || pgv.card(
          r.name,
          CASE WHEN v_elem_cnt = 0
            THEN pgv.empty(pgv.t('document.empty_no_canvas'))
            ELSE pgv.svg_canvas(v_svg, '{"height":"200px","toolbar":false}'::jsonb)
          END,
          r.format || ' ' || r.orientation || ' · ' || v_elem_cnt || ' éléments'
        )
        || '</a>'
      );
    END LOOP;
    v_body := v_body || pgv.grid(VARIADIC v_cards);
  END IF;

  -- Documents section
  IF v_total_doc > 0 THEN
    v_body := v_body || '<h3>' || pgv.t('document.stat_documents') || '</h3>';
    v_body := v_body || pgv.table(jsonb_build_object(
      'rpc',     'data_documents',
      'schema',  'document',
      'filters', jsonb_build_array(
        jsonb_build_object('name','p_doc_type','type','select','label', pgv.t('document.field_doc_type'),
          'options', jsonb_build_array(
            jsonb_build_array('', pgv.t('document.filter_all')),
            jsonb_build_array('facture', pgv.t('document.type_facture')),
            jsonb_build_array('devis', pgv.t('document.type_devis')),
            jsonb_build_array('bon_commande', pgv.t('document.type_bon_commande')),
            jsonb_build_array('bon_livraison', pgv.t('document.type_bon_livraison')),
            jsonb_build_array('avoir', pgv.t('document.type_avoir')))),
        jsonb_build_object('name','p_status','type','select','label', pgv.t('document.field_status'),
          'options', jsonb_build_array(
            jsonb_build_array('', pgv.t('document.filter_all')),
            jsonb_build_array('draft', pgv.t('document.status_draft')),
            jsonb_build_array('generated', pgv.t('document.status_generated')),
            jsonb_build_array('signed', pgv.t('document.status_signed')),
            jsonb_build_array('archived', pgv.t('document.status_archived')))),
        jsonb_build_object('name','q','type','search','label', pgv.t('document.field_search'))
      ),
      'cols', jsonb_build_array(
        jsonb_build_object('key','id','label','#','hidden',true),
        jsonb_build_object('key','title','label', pgv.t('document.col_title')),
        jsonb_build_object('key','doc_type','label', pgv.t('document.col_doc_type')),
        jsonb_build_object('key','ref_module','label', pgv.t('document.col_module')),
        jsonb_build_object('key','ref_id','label', pgv.t('document.col_ref')),
        jsonb_build_object('key','status','label', pgv.t('document.col_status'),'class','pgv-col-badge'),
        jsonb_build_object('key','created','label', pgv.t('document.col_created'))
      ),
      'page_size', 20
    ));
  END IF;

  RETURN v_body;
END;
$function$;
