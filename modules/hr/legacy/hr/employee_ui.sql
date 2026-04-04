CREATE OR REPLACE FUNCTION hr.employee_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_emp hr.employee;
  v_balances jsonb[];
  v_bal record;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading('Salariés'),
        pgv.ui_table('employees', jsonb_build_array(
          pgv.ui_col('display_name', 'Nom', pgv.ui_link('{display_name}', '/hr/employee/{id}')),
          pgv.ui_col('matricule', 'Matricule'),
          pgv.ui_col('poste', 'Poste'),
          pgv.ui_col('departement', 'Département'),
          pgv.ui_col('contrat_label', 'Contrat', pgv.ui_badge('{contrat_label}')),
          pgv.ui_col('date_embauche', 'Embauche'),
          pgv.ui_col('statut', 'Statut', pgv.ui_badge('{statut}'))
        ))
      ),
      'datasources', jsonb_build_object(
        'employees', pgv.ui_datasource('hr://employee', 20, true, 'nom')
      )
    );
  END IF;

  -- Detail mode
  SELECT * INTO v_emp FROM hr.employee WHERE id = p_slug::int AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  -- Collect leave balances
  v_balances := ARRAY[]::jsonb[];
  FOR v_bal IN
    SELECT lb.leave_type, lb.allocated, lb.used, (lb.allocated - lb.used) AS remaining
      FROM hr.leave_balance lb
     WHERE lb.employee_id = v_emp.id
     ORDER BY lb.leave_type
  LOOP
    v_balances := v_balances || jsonb_build_object(
      'type', 'text',
      'value', hr.absence_label(v_bal.leave_type) || ' : ' || v_bal.remaining || 'j / ' || v_bal.allocated || 'j'
    );
  END LOOP;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      -- Header
      pgv.ui_row(
        pgv.ui_link('← Salariés', '/hr'),
        pgv.ui_heading(v_emp.prenom || ' ' || v_emp.nom)
      ),
      pgv.ui_row(
        pgv.ui_badge(upper(v_emp.statut)),
        pgv.ui_badge(hr.contrat_label(v_emp.type_contrat))
      ),

      -- Identité
      pgv.ui_heading('Identité', 3),
      pgv.ui_row(
        pgv.ui_text('Matricule : ' || CASE WHEN v_emp.matricule = '' THEN '—' ELSE v_emp.matricule END),
        pgv.ui_text('Email : ' || COALESCE(v_emp.email, '—')),
        pgv.ui_text('Tél : ' || COALESCE(v_emp.phone, '—'))
      ),
      pgv.ui_row(
        pgv.ui_text('Naissance : ' || CASE WHEN v_emp.date_naissance IS NOT NULL THEN to_char(v_emp.date_naissance, 'DD/MM/YYYY') ELSE '—' END),
        pgv.ui_text('Sexe : ' || CASE v_emp.sexe WHEN 'M' THEN 'Homme' WHEN 'F' THEN 'Femme' ELSE '—' END),
        pgv.ui_text('Nationalité : ' || CASE WHEN v_emp.nationalite = '' THEN '—' ELSE v_emp.nationalite END)
      ),

      -- Poste
      pgv.ui_heading('Poste', 3),
      pgv.ui_row(
        pgv.ui_text('Poste : ' || CASE WHEN v_emp.poste = '' THEN '—' ELSE v_emp.poste END),
        pgv.ui_text('Département : ' || CASE WHEN v_emp.departement = '' THEN '—' ELSE v_emp.departement END),
        pgv.ui_text('Qualification : ' || CASE WHEN v_emp.qualification = '' THEN '—' ELSE v_emp.qualification END)
      ),

      -- Contrat
      pgv.ui_heading('Contrat', 3),
      pgv.ui_row(
        pgv.ui_text('Embauche : ' || to_char(v_emp.date_embauche, 'DD/MM/YYYY')),
        pgv.ui_text('Fin : ' || CASE WHEN v_emp.date_fin IS NOT NULL THEN to_char(v_emp.date_fin, 'DD/MM/YYYY') ELSE '—' END),
        pgv.ui_text('Heures/sem : ' || v_emp.heures_hebdo || 'h')
      ),

      -- Soldes congés (si existants)
      CASE WHEN cardinality(v_balances) > 0 THEN
        pgv.ui_column(
          pgv.ui_heading('Soldes congés', 3),
          pgv.ui_row(VARIADIC v_balances)
        )
      ELSE
        pgv.ui_text('')
      END,

      -- Notes
      CASE WHEN v_emp.notes != '' THEN
        pgv.ui_column(
          pgv.ui_heading('Notes', 3),
          pgv.ui_text(v_emp.notes)
        )
      ELSE
        pgv.ui_text('')
      END
    )
  );
END;
$function$;
