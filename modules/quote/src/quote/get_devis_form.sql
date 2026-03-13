CREATE OR REPLACE FUNCTION quote.get_devis_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_fields text;
  d record;
  v_objet text := '';
  v_validite int := 30;
  v_notes text := '';
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO d FROM quote.devis WHERE id = p_id;
    IF NOT FOUND THEN RETURN pgv.empty(pgv.t('quote.empty_not_found_devis')); END IF;
    IF d.statut <> 'brouillon' THEN
      RETURN pgv.empty(pgv.t('quote.empty_modification_impossible'), pgv.t('quote.empty_brouillons_only'));
    END IF;
    v_objet := d.objet;
    v_validite := d.validite_jours;
    v_notes := d.notes;
  END IF;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[
    pgv.t('quote.title_devis'), pgv.call_ref('get_devis'),
    CASE WHEN p_id IS NOT NULL THEN pgv.t('quote.title_modifier') ELSE pgv.t('quote.title_nouveau_devis') END
  ]);

  -- Build form fields
  v_fields := '';
  IF p_id IS NOT NULL THEN
    v_fields := '<input type="hidden" name="id" value="' || p_id || '">';
  END IF;

  -- Client select (raw HTML, _client_options returns HTML)
  v_fields := v_fields
    || '<label>' || pgv.t('quote.field_client') || ' <select name="client_id" required>'
    || '<option value="">' || pgv.t('quote.field_select_placeholder') || '</option>'
    || quote._client_options()
    || '</select></label>';

  IF p_id IS NOT NULL THEN
    v_fields := replace(v_fields,
      'value="' || d.client_id || '">',
      'value="' || d.client_id || '" selected>');
  END IF;

  v_fields := v_fields
    || pgv.input('objet', 'text', pgv.t('quote.field_objet'), v_objet, true)
    || pgv.input('validite_jours', 'number', pgv.t('quote.field_validite_jours'), v_validite::text)
    || pgv.textarea('notes', pgv.t('quote.field_notes'), v_notes);

  v_body := v_body || pgv.form('post_devis_save', v_fields,
    CASE WHEN p_id IS NOT NULL THEN pgv.t('quote.btn_mettre_a_jour') ELSE pgv.t('quote.btn_creer_devis') END);

  RETURN v_body;
END;
$function$;
