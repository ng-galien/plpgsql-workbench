CREATE OR REPLACE FUNCTION hr.absence_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_abs record;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading('Absences'),
        pgv.ui_table('absences', jsonb_build_array(
          pgv.ui_col('employee_name', 'Salarié', pgv.ui_link('{employee_name}', '/hr/employee/{employee_id}')),
          pgv.ui_col('type_label', 'Type', pgv.ui_badge('{type_label}')),
          pgv.ui_col('date_debut', 'Début'),
          pgv.ui_col('date_fin', 'Fin'),
          pgv.ui_col('nb_jours', 'Jours'),
          pgv.ui_col('motif', 'Motif'),
          pgv.ui_col('statut', 'Statut', pgv.ui_badge('{statut}'))
        ))
      ),
      'datasources', jsonb_build_object(
        'absences', pgv.ui_datasource('hr://absence', 20, true, '-date_debut')
      )
    );
  END IF;

  -- Detail mode
  SELECT a.*, e.prenom || ' ' || e.nom AS employee_name
    INTO v_abs
    FROM hr.absence a
    JOIN hr.employee e ON e.id = a.employee_id
   WHERE a.id = p_slug::int AND a.tenant_id = current_setting('app.tenant_id', true);

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link('← Absences', '/hr/absences'),
        pgv.ui_heading('Absence — ' || v_abs.employee_name)
      ),
      pgv.ui_row(
        pgv.ui_badge(hr.absence_label(v_abs.type_absence)),
        pgv.ui_badge(upper(v_abs.statut))
      ),
      pgv.ui_row(
        pgv.ui_text('Du ' || to_char(v_abs.date_debut, 'DD/MM/YYYY') || ' au ' || to_char(v_abs.date_fin, 'DD/MM/YYYY')),
        pgv.ui_text(v_abs.nb_jours || ' jour(s)')
      ),
      CASE WHEN v_abs.motif != '' THEN pgv.ui_text('Motif : ' || v_abs.motif) ELSE pgv.ui_text('') END
    )
  );
END;
$function$;
