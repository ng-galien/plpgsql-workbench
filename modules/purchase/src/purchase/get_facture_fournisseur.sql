CREATE OR REPLACE FUNCTION purchase.get_facture_fournisseur(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_fac purchase.facture_fournisseur;
  v_cmd_numero text;
  v_fournisseur_id int;
  v_fournisseur_name text;
  v_body text;
  v_rows text[];
  r record;
BEGIN
  -- Liste si pas d'id
  IF p_id IS NULL THEN
    v_rows := ARRAY[]::text[];
    FOR r IN
      SELECT f.id, f.numero_fournisseur, c.numero AS cmd_numero,
             cl.id AS fournisseur_id, cl.name AS fournisseur,
             f.montant_ttc, f.statut, f.date_facture, f.date_echeance
        FROM purchase.facture_fournisseur f
        LEFT JOIN purchase.commande c ON c.id = f.commande_id
        LEFT JOIN crm.client cl ON cl.id = c.fournisseur_id
       ORDER BY f.created_at DESC
    LOOP
      v_rows := v_rows || ARRAY[
        format('<a href="%s">%s</a>', pgv.call_ref('get_facture_fournisseur', jsonb_build_object('p_id', r.id)), pgv.esc(r.numero_fournisseur)),
        coalesce(format('<a href="/crm/client?p_id=%s">%s</a>', r.fournisseur_id, pgv.esc(r.fournisseur)), '—'),
        coalesce(r.cmd_numero, '—'),
        purchase._statut_badge(r.statut),
        to_char(r.montant_ttc, 'FM999 990.00') || ' EUR',
        to_char(r.date_facture, 'DD/MM/YYYY'),
        coalesce(to_char(r.date_echeance, 'DD/MM/YYYY'), '—')
      ];
    END LOOP;

    IF array_length(v_rows, 1) IS NULL THEN
      RETURN pgv.empty(pgv.t('purchase.empty_no_facture'), pgv.t('purchase.empty_facture_hint'));
    END IF;

    DECLARE
      v_form_body text;
      v_cmd_options jsonb;
    BEGIN
      SELECT coalesce(jsonb_agg(jsonb_build_object('value', id::text, 'label', numero)), '[]'::jsonb)
        INTO v_cmd_options
        FROM (SELECT id, numero FROM purchase.commande ORDER BY created_at DESC LIMIT 20) sub;

      v_form_body := pgv.input('p_numero_fournisseur', 'text', pgv.t('purchase.field_no_fournisseur'), NULL, true)
        || '<div class="pgv-grid">'
        || '<label>' || pgv.t('purchase.field_montant_ht') || '<input type="number" name="p_montant_ht" step="0.01" min="0" required></label>'
        || '<label>' || pgv.t('purchase.field_montant_ttc') || '<input type="number" name="p_montant_ttc" step="0.01" min="0" required></label>'
        || '</div>'
        || '<div class="pgv-grid">'
        || pgv.input('p_date_facture', 'date', pgv.t('purchase.field_date_facture'), NULL, true)
        || pgv.input('p_date_echeance', 'date', pgv.t('purchase.field_date_echeance'))
        || '</div>'
        || pgv.sel('p_commande_id', pgv.t('purchase.field_commande_liee'), v_cmd_options)
        || pgv.textarea('p_notes', pgv.t('purchase.field_notes'));

      RETURN pgv.form_dialog('dlg-saisir-facture', pgv.t('purchase.title_saisir_facture'),
        v_form_body,
        'post_facture_saisir', pgv.t('purchase.btn_saisir'))
      || pgv.md_table(ARRAY[pgv.t('purchase.col_no_fournisseur'), pgv.t('purchase.col_fournisseur'), pgv.t('purchase.col_commande'), pgv.t('purchase.col_statut'), pgv.t('purchase.col_montant_ttc'), pgv.t('purchase.col_date_facture'), pgv.t('purchase.col_echeance')], v_rows);
    END;
  END IF;

  -- Détail
  SELECT * INTO v_fac FROM purchase.facture_fournisseur WHERE id = p_id;
  SELECT numero INTO v_cmd_numero FROM purchase.commande WHERE id = v_fac.commande_id;

  -- Fournisseur via commande
  SELECT c.fournisseur_id, cl.name INTO v_fournisseur_id, v_fournisseur_name
    FROM purchase.commande c
    JOIN crm.client cl ON cl.id = c.fournisseur_id
   WHERE c.id = v_fac.commande_id;

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.card(pgv.t('purchase.card_facture'), pgv.esc(v_fac.numero_fournisseur) || '<br>' || purchase._statut_badge(v_fac.statut)),
    pgv.card(pgv.t('purchase.card_fournisseur'), CASE WHEN v_fournisseur_id IS NOT NULL
      THEN format('<a href="/crm/client?p_id=%s">%s</a>', v_fournisseur_id, pgv.esc(v_fournisseur_name))
      ELSE '—' END),
    pgv.card(pgv.t('purchase.card_commande'), coalesce(v_cmd_numero, '—')),
    pgv.card(pgv.t('purchase.card_montant_ht'), to_char(v_fac.montant_ht, 'FM999 990.00') || ' EUR'),
    pgv.card(pgv.t('purchase.card_montant_ttc'), to_char(v_fac.montant_ttc, 'FM999 990.00') || ' EUR')
  ]);

  -- Workflow progression
  v_body := v_body || pgv.workflow(
    jsonb_build_array(
      jsonb_build_object('key', 'recue', 'label', pgv.t('purchase.wf_recue_fac')),
      jsonb_build_object('key', 'validee', 'label', pgv.t('purchase.wf_validee')),
      jsonb_build_object('key', 'payee', 'label', pgv.t('purchase.wf_payee'))
    ),
    v_fac.statut);

  v_body := v_body || '<p>'
    || '<strong>' || pgv.t('purchase.label_date_facture') || '</strong> ' || to_char(v_fac.date_facture, 'DD/MM/YYYY')
    || ' | <strong>' || pgv.t('purchase.label_echeance') || '</strong> ' || coalesce(to_char(v_fac.date_echeance, 'DD/MM/YYYY'), '—')
    || '</p>';

  IF v_fac.notes <> '' THEN
    v_body := v_body || '<p><strong>' || pgv.t('purchase.label_notes') || '</strong> ' || pgv.esc(v_fac.notes) || '</p>';
  END IF;

  -- Rapprochement: comparer montants commande vs facture
  IF v_fac.commande_id IS NOT NULL THEN
    DECLARE
      v_cmd_ttc numeric;
      v_ecart numeric;
    BEGIN
      v_cmd_ttc := purchase._total_ttc(v_fac.commande_id);
      v_ecart := v_fac.montant_ttc - v_cmd_ttc;
      v_body := v_body || '<p><strong>' || pgv.t('purchase.label_rapprochement') || '</strong> ' || pgv.t('purchase.label_commande_ttc') || ' '
        || to_char(v_cmd_ttc, 'FM999 990.00') || ' EUR'
        || ' | ' || pgv.t('purchase.label_ecart') || ' ' || to_char(v_ecart, 'FM999 990.00') || ' EUR';
      IF abs(v_ecart) > 0.01 THEN
        v_body := v_body || ' ' || pgv.badge(pgv.t('purchase.badge_ecart'), 'warning');
      ELSE
        v_body := v_body || ' ' || pgv.badge(pgv.t('purchase.badge_ok'), 'success');
      END IF;
      v_body := v_body || '</p>';
    END;
  END IF;

  -- Actions
  v_body := v_body || '<p>';
  IF v_fac.statut = 'recue' THEN
    v_body := v_body || pgv.action('post_facture_valider', pgv.t('purchase.btn_valider'),
      jsonb_build_object('p_id', p_id),
      pgv.t('purchase.confirm_valider_facture'));
  ELSIF v_fac.statut = 'validee' THEN
    v_body := v_body || pgv.action('post_facture_payer', pgv.t('purchase.btn_payer'),
      jsonb_build_object('p_id', p_id),
      pgv.t('purchase.confirm_payer'));
  ELSIF v_fac.statut = 'payee' AND NOT v_fac.comptabilisee THEN
    v_body := v_body || pgv.action('post_facture_comptabiliser', pgv.t('purchase.btn_comptabiliser'),
      jsonb_build_object('p_id', p_id),
      pgv.t('purchase.confirm_comptabiliser'));
  END IF;
  IF v_fac.comptabilisee THEN
    v_body := v_body || ' ' || pgv.badge(pgv.t('purchase.badge_comptabilisee'), 'success');
  END IF;
  v_body := v_body || '</p>';

  RETURN v_body;
END;
$function$;
