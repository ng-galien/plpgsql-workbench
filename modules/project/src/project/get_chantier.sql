CREATE OR REPLACE FUNCTION project.get_chantier(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  c record;
  v_client_name text;
  v_devis_numero text;
  v_body text;
  v_pct numeric;
  v_heures_total numeric;
  v_rows_j text[];
  v_rows_p text[];
  v_rows_n text[];
  v_rows_a text[];
  r record;
  v_has_expense boolean;
  v_total_frais numeric;
  v_expense_rows text[];
BEGIN
  SELECT * INTO c FROM project.chantier WHERE id = p_id;
  IF NOT FOUND THEN RETURN pgv.empty(pgv.t('project.empty_introuvable')); END IF;

  SELECT name INTO v_client_name FROM crm.client WHERE id = c.client_id;
  IF c.devis_id IS NOT NULL THEN
    SELECT numero INTO v_devis_numero FROM quote.devis WHERE id = c.devis_id;
  END IF;

  v_pct := project._avancement_global(p_id);

  SELECT COALESCE(sum(heures), 0) INTO v_heures_total
    FROM project.pointage WHERE chantier_id = p_id;

  -- Check if expense module has chantier_id on note (via pg_catalog)
  SELECT EXISTS(
    SELECT 1 FROM pg_catalog.pg_attribute a
      JOIN pg_catalog.pg_class cl ON cl.oid = a.attrelid
      JOIN pg_catalog.pg_namespace ns ON ns.oid = cl.relnamespace
     WHERE ns.nspname = 'expense' AND cl.relname = 'note'
       AND a.attname = 'chantier_id' AND NOT a.attisdropped
  ) INTO v_has_expense;

  -- Fetch expense data if available
  v_total_frais := 0;
  v_expense_rows := ARRAY[]::text[];
  IF v_has_expense THEN
    EXECUTE format(
      'SELECT COALESCE(sum(l.montant_ttc), 0)
         FROM expense.note n JOIN expense.ligne l ON l.note_id = n.id
        WHERE n.chantier_id = %s', p_id
    ) INTO v_total_frais;

    EXECUTE format(
      $q$SELECT array_agg(x ORDER BY x.rn) FROM (
        SELECT row_number() OVER () AS rn,
               format('<a href="/expense/note?p_id=%%s">%%s</a>', n.id, pgv.esc(COALESCE(n.reference, '#' || n.id))),
               pgv.esc(n.auteur),
               to_char(n.date_debut, 'DD/MM/YYYY') || ' -> ' || to_char(n.date_fin, 'DD/MM/YYYY'),
               pgv.badge(
                 CASE n.statut WHEN 'brouillon' THEN pgv.t('project.expense_brouillon') WHEN 'soumise' THEN pgv.t('project.expense_soumise') WHEN 'validee' THEN pgv.t('project.expense_validee') WHEN 'refusee' THEN pgv.t('project.expense_refusee') ELSE n.statut END,
                 CASE n.statut WHEN 'brouillon' THEN 'default' WHEN 'soumise' THEN 'info' WHEN 'validee' THEN 'success' WHEN 'refusee' THEN 'danger' ELSE 'default' END
               ),
               to_char(COALESCE(sum(l.montant_ttc), 0), 'FM999 999.00') || ' €'
          FROM expense.note n
          LEFT JOIN expense.ligne l ON l.note_id = n.id
         WHERE n.chantier_id = %s
         GROUP BY n.id ORDER BY n.date_debut DESC
      ) x$q$, p_id
    ) INTO v_expense_rows;

    IF v_expense_rows IS NULL THEN v_expense_rows := ARRAY[]::text[]; END IF;
  END IF;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[
    pgv.t('project.bc_projets'), pgv.call_ref('get_chantiers'),
    c.numero
  ]);

  -- Workflow bar (statut)
  v_body := v_body || pgv.workflow(
    jsonb_build_array(
      jsonb_build_object('key', 'preparation', 'label', pgv.t('project.statut_preparation')),
      jsonb_build_object('key', 'execution', 'label', pgv.t('project.statut_execution')),
      jsonb_build_object('key', 'reception', 'label', pgv.t('project.statut_reception')),
      jsonb_build_object('key', 'clos', 'label', pgv.t('project.statut_clos'))
    ),
    c.statut
  );

  -- Progress bar (avancement)
  v_body := v_body || pgv.progress(v_pct, 100, pgv.t('project.title_avancement'));

  -- Header stats
  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('project.stat_heures_totales'), v_heures_total::text || ' h'),
    pgv.stat(pgv.t('project.stat_client'), format('<a href="/crm/client?p_id=%s">%s</a>', c.client_id, pgv.esc(v_client_name)))
  ] || CASE WHEN v_has_expense AND v_total_frais > 0
    THEN ARRAY[pgv.stat(pgv.t('project.stat_frais'), to_char(v_total_frais, 'FM999 999.00') || ' €')]
    ELSE ARRAY[]::text[]
  END);

  -- Info card
  v_body := v_body || pgv.card(pgv.t('project.title_informations'),
    pgv.dl(VARIADIC ARRAY[
      pgv.t('project.dl_objet'), pgv.esc(c.objet),
      pgv.t('project.dl_adresse'), CASE WHEN c.adresse = '' THEN '—' ELSE pgv.esc(c.adresse) END,
      pgv.t('project.dl_devis'), CASE WHEN v_devis_numero IS NOT NULL THEN format('<a href="/quote/devis?p_id=%s">%s</a>', c.devis_id, pgv.esc(v_devis_numero)) ELSE '—' END,
      pgv.t('project.dl_debut'), COALESCE(to_char(c.date_debut, 'DD/MM/YYYY'), '—'),
      pgv.t('project.dl_fin_prevue'), COALESCE(to_char(c.date_fin_prevue, 'DD/MM/YYYY'), '—'),
      pgv.t('project.dl_fin_reelle'), COALESCE(to_char(c.date_fin_reelle, 'DD/MM/YYYY'), '—')
    ])
  );

  -- Actions
  v_body := v_body || '<p>';
  IF c.statut = 'preparation' THEN
    v_body := v_body
      || pgv.action('post_chantier_demarrer', pgv.t('project.btn_demarrer'), jsonb_build_object('p_id', p_id), pgv.t('project.confirm_demarrer'))
      || ' '
      || format('<a href="%s" role="button" class="outline">%s</a>', pgv.call_ref('get_chantier_form', jsonb_build_object('p_id', p_id)), pgv.t('project.btn_modifier'))
      || ' '
      || pgv.action('post_chantier_supprimer', pgv.t('project.btn_supprimer'), jsonb_build_object('p_id', p_id), pgv.t('project.confirm_supprimer'), 'danger');
  ELSIF c.statut = 'execution' THEN
    v_body := v_body
      || pgv.action('post_chantier_reception', pgv.t('project.btn_reception'), jsonb_build_object('p_id', p_id), pgv.t('project.confirm_reception'))
      || ' '
      || format('<a href="%s" role="button" class="outline">%s</a>', pgv.call_ref('get_chantier_form', jsonb_build_object('p_id', p_id)), pgv.t('project.btn_modifier'));
  ELSIF c.statut = 'reception' THEN
    v_body := v_body
      || pgv.action('post_chantier_clore', pgv.t('project.btn_clore'), jsonb_build_object('p_id', p_id), pgv.t('project.confirm_clore'));
  END IF;
  v_body := v_body || '</p>';

  -- Jalons
  v_rows_j := ARRAY[]::text[];
  FOR r IN
    SELECT * FROM project.jalon WHERE chantier_id = p_id ORDER BY sort_order, id
  LOOP
    v_rows_j := v_rows_j || ARRAY[
      r.sort_order::text,
      pgv.esc(r.label),
      pgv.badge(
        CASE r.statut WHEN 'a_faire' THEN pgv.t('project.statut_a_faire') WHEN 'en_cours' THEN pgv.t('project.statut_en_cours') ELSE pgv.t('project.statut_valide') END,
        CASE r.statut WHEN 'a_faire' THEN 'default' WHEN 'en_cours' THEN 'info' ELSE 'success' END
      ),
      r.pct_avancement::text || ' %',
      COALESCE(to_char(r.date_prevue, 'DD/MM/YYYY'), '—'),
      CASE WHEN c.statut IN ('preparation','execution') THEN
        pgv.action('post_jalon_avancer', '% ', jsonb_build_object('p_id', r.id, 'p_pct', LEAST(r.pct_avancement + 25, 100)))
        || ' '
        || CASE WHEN r.statut <> 'valide' THEN pgv.action('post_jalon_valider', pgv.t('project.btn_valider'), jsonb_build_object('p_id', r.id), NULL, 'outline') ELSE '' END
        || ' '
        || pgv.action('post_jalon_supprimer', 'X', jsonb_build_object('p_id', r.id), pgv.t('project.confirm_supprimer_jalon'), 'danger')
      ELSE '' END
    ];
  END LOOP;

  -- Pointages
  v_rows_p := ARRAY[]::text[];
  FOR r IN
    SELECT * FROM project.pointage WHERE chantier_id = p_id ORDER BY date_pointage DESC, id DESC LIMIT 50
  LOOP
    v_rows_p := v_rows_p || ARRAY[
      to_char(r.date_pointage, 'DD/MM/YYYY'),
      r.heures::text || ' h',
      pgv.esc(r.description),
      CASE WHEN c.statut IN ('preparation','execution') THEN
        pgv.action('post_pointage_supprimer', 'X', jsonb_build_object('p_id', r.id), pgv.t('project.confirm_supprimer_pointage'), 'danger')
      ELSE '' END
    ];
  END LOOP;

  -- Notes
  v_rows_n := ARRAY[]::text[];
  FOR r IN
    SELECT * FROM project.note_chantier WHERE chantier_id = p_id ORDER BY created_at DESC LIMIT 50
  LOOP
    v_rows_n := v_rows_n || ARRAY[
      to_char(r.created_at, 'DD/MM/YYYY HH24:MI'),
      pgv.esc(r.contenu),
      CASE WHEN c.statut IN ('preparation','execution') THEN
        pgv.action('post_note_supprimer', 'X', jsonb_build_object('p_id', r.id), pgv.t('project.confirm_supprimer_note'), 'danger')
      ELSE '' END
    ];
  END LOOP;

  -- Équipe (affectations)
  v_rows_a := ARRAY[]::text[];
  FOR r IN
    SELECT * FROM project.affectation WHERE chantier_id = p_id ORDER BY id
  LOOP
    v_rows_a := v_rows_a || ARRAY[
      pgv.esc(r.nom_intervenant),
      CASE WHEN r.role = '' THEN '—' ELSE pgv.esc(r.role) END,
      CASE WHEN r.heures_prevues IS NOT NULL THEN r.heures_prevues::text || ' h' ELSE '—' END,
      CASE WHEN c.statut IN ('preparation','execution') THEN
        pgv.action('post_affectation_supprimer', 'X', jsonb_build_object('p_id', r.id), pgv.t('project.confirm_retirer_intervenant'), 'danger')
      ELSE '' END
    ];
  END LOOP;

  v_body := v_body || pgv.tabs(VARIADIC ARRAY[
    pgv.t('project.tab_jalons') || ' (' || COALESCE(array_length(v_rows_j, 1) / 6, 0) || ')',
    CASE WHEN array_length(v_rows_j, 1) IS NULL
      THEN pgv.empty(pgv.t('project.empty_aucun_jalon'))
      ELSE pgv.md_table(ARRAY[pgv.t('project.col_order'), pgv.t('project.col_jalon'), pgv.t('project.col_statut'), pgv.t('project.col_avancement'), pgv.t('project.col_date_prevue'), pgv.t('project.col_actions')], v_rows_j)
    END
    || CASE WHEN c.statut IN ('preparation','execution') THEN
      pgv.form('post_jalon_ajouter',
        '<input type="hidden" name="p_chantier_id" value="' || p_id || '">'
        || pgv.input('p_label', 'text', pgv.t('project.ph_nouveau_jalon'), NULL, true),
        pgv.t('project.btn_ajouter'))
    ELSE '' END,

    pgv.t('project.tab_equipe') || ' (' || COALESCE(array_length(v_rows_a, 1) / 4, 0) || ')',
    CASE WHEN array_length(v_rows_a, 1) IS NULL
      THEN pgv.empty(pgv.t('project.empty_aucun_intervenant'))
      ELSE pgv.md_table(ARRAY[pgv.t('project.col_intervenant'), pgv.t('project.col_role'), pgv.t('project.col_heures_prevues'), ''], v_rows_a)
    END
    || CASE WHEN c.statut IN ('preparation','execution') THEN
      pgv.form('post_affectation_ajouter',
        '<input type="hidden" name="p_chantier_id" value="' || p_id || '">'
        || pgv.input('p_nom_intervenant', 'text', pgv.t('project.ph_nom_intervenant'), NULL, true)
        || pgv.input('p_role', 'text', pgv.t('project.ph_role'))
        || pgv.input('p_heures_prevues', 'number', pgv.t('project.ph_heures')),
        pgv.t('project.btn_ajouter'))
    ELSE '' END,

    pgv.t('project.tab_pointages') || ' (' || COALESCE(array_length(v_rows_p, 1) / 4, 0) || ')',
    CASE WHEN array_length(v_rows_p, 1) IS NULL
      THEN pgv.empty(pgv.t('project.empty_aucun_pointage'))
      ELSE pgv.md_table(ARRAY[pgv.t('project.col_date'), pgv.t('project.col_heures'), pgv.t('project.col_description'), ''], v_rows_p, 10)
    END
    || CASE WHEN c.statut IN ('preparation','execution') THEN
      pgv.form('post_pointage_ajouter',
        '<input type="hidden" name="p_chantier_id" value="' || p_id || '">'
        || pgv.input('p_date', 'date', pgv.t('project.field_date'), CURRENT_DATE::text)
        || pgv.input('p_heures', 'number', pgv.t('project.ph_heures'), NULL, true)
        || pgv.input('p_description', 'text', pgv.t('project.ph_description')),
        pgv.t('project.btn_ajouter'))
    ELSE '' END,

    pgv.t('project.tab_notes') || ' (' || COALESCE(array_length(v_rows_n, 1) / 3, 0) || ')',
    CASE WHEN array_length(v_rows_n, 1) IS NULL
      THEN pgv.empty(pgv.t('project.empty_aucune_note'))
      ELSE pgv.md_table(ARRAY[pgv.t('project.col_date'), pgv.t('project.col_contenu'), ''], v_rows_n, 10)
    END
    || CASE WHEN c.statut IN ('preparation','execution') THEN
      pgv.form('post_note_ajouter',
        '<input type="hidden" name="p_chantier_id" value="' || p_id || '">'
        || pgv.textarea('p_contenu', pgv.t('project.ph_nouvelle_note')),
        pgv.t('project.btn_ajouter'))
    ELSE '' END
  ] || CASE WHEN v_has_expense THEN ARRAY[
    pgv.t('project.tab_frais') || ' (' || COALESCE(array_length(v_expense_rows, 1) / 5, 0) || ')',
    CASE WHEN array_length(v_expense_rows, 1) IS NULL
      THEN pgv.empty(pgv.t('project.empty_aucun_frais'))
      ELSE pgv.md_table(ARRAY[pgv.t('project.col_reference'), pgv.t('project.col_auteur'), pgv.t('project.col_periode'), pgv.t('project.col_statut'), pgv.t('project.col_total_ttc')], v_expense_rows)
    END
  ] ELSE ARRAY[]::text[] END);

  RETURN v_body;
END;
$function$;
