CREATE OR REPLACE FUNCTION hr.timesheet_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_ts record;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading('Heures'),
        pgv.ui_table('timesheets', jsonb_build_array(
          pgv.ui_col('employee_name', 'Salarié', pgv.ui_link('{employee_name}', '/hr/employee/{employee_id}')),
          pgv.ui_col('date_travail', 'Date'),
          pgv.ui_col('heures', 'Heures'),
          pgv.ui_col('description', 'Description')
        ))
      ),
      'datasources', jsonb_build_object(
        'timesheets', pgv.ui_datasource('hr://timesheet', 20, true, '-date_travail')
      )
    );
  END IF;

  -- Detail mode
  SELECT t.*, e.prenom || ' ' || e.nom AS employee_name
    INTO v_ts
    FROM hr.timesheet t
    JOIN hr.employee e ON e.id = t.employee_id
   WHERE t.id = p_slug::int AND t.tenant_id = current_setting('app.tenant_id', true);

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link('← Heures', '/hr/timesheet'),
        pgv.ui_heading('Pointage — ' || v_ts.employee_name)
      ),
      pgv.ui_row(
        pgv.ui_text('Date : ' || to_char(v_ts.date_travail, 'DD/MM/YYYY')),
        pgv.ui_text(v_ts.heures || 'h')
      ),
      CASE WHEN v_ts.description != '' THEN pgv.ui_text('Description : ' || v_ts.description) ELSE pgv.ui_text('') END
    )
  );
END;
$function$;
