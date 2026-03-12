CREATE OR REPLACE FUNCTION ledger.get_entry(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_entry record;
  v_body text;
  v_rows text[];
  v_total_debit numeric := 0;
  v_total_credit numeric := 0;
  v_balanced boolean;
  v_accounts_options text;
  r record;
BEGIN
  SELECT * INTO v_entry FROM ledger.journal_entry WHERE id = p_id;
  IF NOT FOUND THEN RETURN pgv.empty('Écriture introuvable'); END IF;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[
    'Écritures', pgv.call_ref('get_entries'),
    v_entry.reference
  ]);

  v_body := v_body || pgv.dl(VARIADIC ARRAY[
    'Date', to_char(v_entry.entry_date, 'DD/MM/YYYY'),
    'Référence', pgv.esc(v_entry.reference),
    'Description', pgv.esc(v_entry.description),
    'Statut', CASE WHEN v_entry.posted THEN pgv.badge('Validée', 'success') ELSE pgv.badge('Brouillon', 'warning') END
  ]);

  -- Lignes
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT el.id, el.account_id, a.code, a.label AS account_label,
           el.debit, el.credit, el.label
      FROM ledger.entry_line el
      JOIN ledger.account a ON a.id = el.account_id
     WHERE el.journal_entry_id = p_id
     ORDER BY el.id
  LOOP
    v_total_debit := v_total_debit + r.debit;
    v_total_credit := v_total_credit + r.credit;
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a> %s', pgv.call_ref('get_account', jsonb_build_object('p_id', r.account_id)), pgv.esc(r.code), pgv.esc(r.account_label)),
      pgv.esc(r.label),
      CASE WHEN r.debit > 0 THEN to_char(r.debit, 'FM999 990.00') ELSE '' END,
      CASE WHEN r.credit > 0 THEN to_char(r.credit, 'FM999 990.00') ELSE '' END,
      CASE WHEN NOT v_entry.posted
        THEN pgv.action('post_line_delete', 'Suppr.', jsonb_build_object('id', r.id, 'entry_id', p_id), 'Supprimer cette ligne ?', 'danger')
        ELSE ''
      END
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty('Aucune ligne', 'Ajoutez des lignes à cette écriture.');
  ELSE
    -- Add totals row
    v_rows := v_rows || ARRAY[
      '<strong>Total</strong>', '',
      '<strong>' || to_char(v_total_debit, 'FM999 990.00') || '</strong>',
      '<strong>' || to_char(v_total_credit, 'FM999 990.00') || '</strong>',
      ''
    ];
    v_body := v_body || pgv.md_table(
      ARRAY['Compte', 'Libellé', 'Débit', 'Crédit', ''],
      v_rows
    );
  END IF;

  -- Alert si déséquilibrée
  v_balanced := ledger._entry_balanced(p_id);
  IF NOT v_balanced AND v_total_debit + v_total_credit > 0 THEN
    v_body := v_body || pgv.alert(
      'Écriture déséquilibrée : débit ' || to_char(v_total_debit, 'FM999 990.00')
        || ' € ≠ crédit ' || to_char(v_total_credit, 'FM999 990.00') || ' €',
      'danger'
    );
  END IF;

  -- Formulaire ajout ligne (brouillon uniquement)
  IF NOT v_entry.posted THEN
    -- Build account options
    v_accounts_options := '';
    FOR r IN SELECT id, code, label FROM ledger.account WHERE active ORDER BY code LOOP
      v_accounts_options := v_accounts_options
        || '<option value="' || r.id || '">' || pgv.esc(r.code) || ' — ' || pgv.esc(r.label) || '</option>';
    END LOOP;

    v_body := v_body || '<details><summary>Ajouter une ligne</summary>'
      || '<form data-rpc="post_line_add">'
      || '<input type="hidden" name="entry_id" value="' || p_id || '">'
      || '<label>Compte <select name="account_id" required>'
      || '<option value="">— Choisir —</option>'
      || v_accounts_options
      || '</select></label>'
      || '<div class="grid">'
      || '<label>Débit <input type="number" name="debit" value="0" step="0.01" min="0"></label>'
      || '<label>Crédit <input type="number" name="credit" value="0" step="0.01" min="0"></label>'
      || '</div>'
      || '<label>Libellé <input type="text" name="label" value=""></label>'
      || '<button type="submit">Ajouter</button>'
      || '</form></details>';

    -- Actions brouillon
    v_body := v_body || '<div class="grid">'
      || format('<a href="%s" role="button" class="outline">Modifier</a>', pgv.call_ref('get_entry_form', jsonb_build_object('p_id', p_id)))
      || pgv.action('post_entry_post', 'Valider', jsonb_build_object('id', p_id), 'Valider cette écriture ? Elle deviendra immutable.')
      || pgv.action('post_entry_delete', 'Supprimer', jsonb_build_object('id', p_id), 'Supprimer ce brouillon ?', 'danger')
      || '</div>';
  END IF;

  RETURN v_body;
END;
$function$;
