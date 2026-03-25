CREATE OR REPLACE FUNCTION hr.employee_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
  v_actions jsonb := '[]'::jsonb;
  v_statut text;
  v_cp numeric;
  v_rtt numeric;
  v_heures numeric;
  v_absence_count int;
BEGIN
  SELECT to_jsonb(e) || jsonb_build_object(
    'contrat_label', hr.contrat_label(e.type_contrat),
    'display_name', e.prenom || ' ' || e.nom
  ) INTO v_result
  FROM hr.employee e
  WHERE e.id = p_id::int AND e.tenant_id = current_setting('app.tenant_id', true);

  IF v_result IS NULL THEN RETURN NULL; END IF;

  v_statut := v_result->>'statut';

  -- HATEOAS actions based on state
  IF v_statut = 'actif' THEN
    v_actions := jsonb_build_array(
      jsonb_build_object('method', 'deactivate', 'uri', 'hr://employee/' || p_id || '/deactivate'),
      jsonb_build_object('method', 'delete', 'uri', 'hr://employee/' || p_id || '/delete')
    );
  ELSIF v_statut = 'inactif' THEN
    v_actions := jsonb_build_array(
      jsonb_build_object('method', 'activate', 'uri', 'hr://employee/' || p_id || '/activate'),
      jsonb_build_object('method', 'delete', 'uri', 'hr://employee/' || p_id || '/delete')
    );
  END IF;

  -- Stats: leave balance + hours + absence count
  SELECT COALESCE(lb.allocated - lb.used, 0) INTO v_cp
    FROM hr.leave_balance lb WHERE lb.employee_id = p_id::int AND lb.leave_type = 'conge_paye';
  SELECT COALESCE(lb.allocated - lb.used, 0) INTO v_rtt
    FROM hr.leave_balance lb WHERE lb.employee_id = p_id::int AND lb.leave_type = 'rtt';
  SELECT COALESCE(sum(t.heures), 0) INTO v_heures
    FROM hr.timesheet t WHERE t.employee_id = p_id::int AND t.date_travail >= CURRENT_DATE - 30;
  SELECT count(*) INTO v_absence_count
    FROM hr.absence a WHERE a.employee_id = p_id::int;

  v_result := v_result || jsonb_build_object(
    'actions', v_actions,
    'cp_remaining', COALESCE(v_cp, 0),
    'rtt_remaining', COALESCE(v_rtt, 0),
    'heures_30j', v_heures,
    'absence_count', v_absence_count
  );

  RETURN v_result;
END;
$function$;
