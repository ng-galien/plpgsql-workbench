CREATE OR REPLACE FUNCTION project.get_chantier(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
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
  IF NOT FOUND THEN RETURN pgv.empty('Chantier introuvable'); END IF;

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
               to_char(n.date_debut, 'DD/MM/YYYY') || ' → ' || to_char(n.date_fin, 'DD/MM/YYYY'),
               pgv.badge(
                 CASE n.statut WHEN 'brouillon' THEN 'Brouillon' WHEN 'soumise' THEN 'Soumise' WHEN 'validee' THEN 'Validée' WHEN 'refusee' THEN 'Refusée' ELSE n.statut END,
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
    'Chantiers', pgv.call_ref('get_chantiers'),
    c.numero
  ]);

  -- Workflow bar (statut)
  v_body := v_body || pgv.workflow(
    '[{"key":"preparation","label":"Préparation"},{"key":"execution","label":"Exécution"},{"key":"reception","label":"Réception"},{"key":"clos","label":"Clos"}]'::jsonb,
    c.statut
  );

  -- Progress bar (avancement)
  v_body := v_body || pgv.progress(v_pct, 100, 'Avancement');

  -- Header stats
  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    pgv.stat('Heures totales', v_heures_total::text || ' h'),
    pgv.stat('Client', format('<a href="/crm/client?p_id=%s">%s</a>', c.client_id, pgv.esc(v_client_name)))
  ] || CASE WHEN v_has_expense AND v_total_frais > 0
    THEN ARRAY[pgv.stat('Frais', to_char(v_total_frais, 'FM999 999.00') || ' €')]
    ELSE ARRAY[]::text[]
  END);

  -- Info card
  v_body := v_body || pgv.card('Informations',
    pgv.dl(VARIADIC ARRAY[
      'Objet', pgv.esc(c.objet),
      'Adresse', CASE WHEN c.adresse = '' THEN '—' ELSE pgv.esc(c.adresse) END,
      'Devis', CASE WHEN v_devis_numero IS NOT NULL THEN format('<a href="/quote/devis?p_id=%s">%s</a>', c.devis_id, pgv.esc(v_devis_numero)) ELSE '—' END,
      'Début', COALESCE(to_char(c.date_debut, 'DD/MM/YYYY'), '—'),
      'Fin prévue', COALESCE(to_char(c.date_fin_prevue, 'DD/MM/YYYY'), '—'),
      'Fin réelle', COALESCE(to_char(c.date_fin_reelle, 'DD/MM/YYYY'), '—')
    ])
  );

  -- Actions
  v_body := v_body || '<p>';
  IF c.statut = 'preparation' THEN
    v_body := v_body
      || pgv.action('post_chantier_demarrer', 'Démarrer', jsonb_build_object('p_id', p_id), 'Démarrer ce chantier ?')
      || ' '
      || format('<a href="%s" role="button" class="outline">Modifier</a>', pgv.call_ref('get_chantier_form', jsonb_build_object('p_id', p_id)))
      || ' '
      || pgv.action('post_chantier_supprimer', 'Supprimer', jsonb_build_object('p_id', p_id), 'Supprimer ce chantier ?', 'danger');
  ELSIF c.statut = 'execution' THEN
    v_body := v_body
      || pgv.action('post_chantier_reception', 'Passer en réception', jsonb_build_object('p_id', p_id), 'Passer ce chantier en réception ?')
      || ' '
      || format('<a href="%s" role="button" class="outline">Modifier</a>', pgv.call_ref('get_chantier_form', jsonb_build_object('p_id', p_id)));
  ELSIF c.statut = 'reception' THEN
    v_body := v_body
      || pgv.action('post_chantier_clore', 'Clore le chantier', jsonb_build_object('p_id', p_id), 'Clore définitivement ce chantier ?');
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
        CASE r.statut WHEN 'a_faire' THEN 'À faire' WHEN 'en_cours' THEN 'En cours' ELSE 'Validé' END,
        CASE r.statut WHEN 'a_faire' THEN 'default' WHEN 'en_cours' THEN 'info' ELSE 'success' END
      ),
      r.pct_avancement::text || ' %',
      COALESCE(to_char(r.date_prevue, 'DD/MM/YYYY'), '—'),
      CASE WHEN c.statut IN ('preparation','execution') THEN
        pgv.action('post_jalon_avancer', '% ', jsonb_build_object('p_id', r.id, 'p_pct', LEAST(r.pct_avancement + 25, 100)))
        || ' '
        || CASE WHEN r.statut <> 'valide' THEN pgv.action('post_jalon_valider', 'Valider', jsonb_build_object('p_id', r.id), NULL, 'outline') ELSE '' END
        || ' '
        || pgv.action('post_jalon_supprimer', 'X', jsonb_build_object('p_id', r.id), 'Supprimer ce jalon ?', 'danger')
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
        pgv.action('post_pointage_supprimer', 'X', jsonb_build_object('p_id', r.id), 'Supprimer ce pointage ?', 'danger')
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
        pgv.action('post_note_supprimer', 'X', jsonb_build_object('p_id', r.id), 'Supprimer cette note ?', 'danger')
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
        pgv.action('post_affectation_supprimer', 'X', jsonb_build_object('p_id', r.id), 'Retirer cet intervenant ?', 'danger')
      ELSE '' END
    ];
  END LOOP;

  v_body := v_body || pgv.tabs(VARIADIC ARRAY[
    'Jalons (' || COALESCE(array_length(v_rows_j, 1) / 6, 0) || ')',
    CASE WHEN array_length(v_rows_j, 1) IS NULL
      THEN pgv.empty('Aucun jalon')
      ELSE pgv.md_table(ARRAY['#', 'Jalon', 'Statut', 'Avancement', 'Date prévue', 'Actions'], v_rows_j)
    END
    || CASE WHEN c.statut IN ('preparation','execution') THEN
      '<form data-rpc="post_jalon_ajouter" class="grid">'
      || '<input type="hidden" name="p_chantier_id" value="' || p_id || '">'
      || '<input type="text" name="p_label" placeholder="Nouveau jalon..." required>'
      || '<button type="submit">Ajouter</button>'
      || '</form>'
    ELSE '' END,

    'Équipe (' || COALESCE(array_length(v_rows_a, 1) / 4, 0) || ')',
    CASE WHEN array_length(v_rows_a, 1) IS NULL
      THEN pgv.empty('Aucun intervenant')
      ELSE pgv.md_table(ARRAY['Intervenant', 'Rôle', 'Heures prévues', ''], v_rows_a)
    END
    || CASE WHEN c.statut IN ('preparation','execution') THEN
      '<form data-rpc="post_affectation_ajouter" class="grid">'
      || '<input type="hidden" name="p_chantier_id" value="' || p_id || '">'
      || '<input type="text" name="p_nom_intervenant" placeholder="Nom intervenant" required>'
      || '<input type="text" name="p_role" placeholder="Rôle">'
      || '<input type="number" name="p_heures_prevues" placeholder="Heures" step="0.5" min="0">'
      || '<button type="submit">Ajouter</button>'
      || '</form>'
    ELSE '' END,

    'Pointages (' || COALESCE(array_length(v_rows_p, 1) / 4, 0) || ')',
    CASE WHEN array_length(v_rows_p, 1) IS NULL
      THEN pgv.empty('Aucun pointage')
      ELSE pgv.md_table(ARRAY['Date', 'Heures', 'Description', ''], v_rows_p, 10)
    END
    || CASE WHEN c.statut IN ('preparation','execution') THEN
      '<form data-rpc="post_pointage_ajouter" class="grid">'
      || '<input type="hidden" name="p_chantier_id" value="' || p_id || '">'
      || '<input type="date" name="p_date" value="' || CURRENT_DATE::text || '">'
      || '<input type="number" name="p_heures" placeholder="Heures" step="0.25" min="0.25" required>'
      || '<input type="text" name="p_description" placeholder="Description...">'
      || '<button type="submit">Ajouter</button>'
      || '</form>'
    ELSE '' END,

    'Notes (' || COALESCE(array_length(v_rows_n, 1) / 3, 0) || ')',
    CASE WHEN array_length(v_rows_n, 1) IS NULL
      THEN pgv.empty('Aucune note')
      ELSE pgv.md_table(ARRAY['Date', 'Contenu', ''], v_rows_n, 10)
    END
    || CASE WHEN c.statut IN ('preparation','execution') THEN
      '<form data-rpc="post_note_ajouter">'
      || '<input type="hidden" name="p_chantier_id" value="' || p_id || '">'
      || '<textarea name="p_contenu" placeholder="Nouvelle note..." required></textarea>'
      || '<button type="submit">Ajouter</button>'
      || '</form>'
    ELSE '' END
  ] || CASE WHEN v_has_expense THEN ARRAY[
    'Notes de frais (' || COALESCE(array_length(v_expense_rows, 1) / 5, 0) || ')',
    CASE WHEN array_length(v_expense_rows, 1) IS NULL
      THEN pgv.empty('Aucune note de frais liée')
      ELSE pgv.md_table(ARRAY['Référence', 'Auteur', 'Période', 'Statut', 'Total TTC'], v_expense_rows)
    END
  ] ELSE ARRAY[]::text[] END);

  RETURN v_body;
END;
$function$;
