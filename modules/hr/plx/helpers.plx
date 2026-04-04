-- Options functions

fn hr.gender_options() -> jsonb [stable]:
  return """
    select jsonb_agg(jsonb_build_object('value', v, 'label', l) order by o)
    from (values ('M', 'hr.gender_m', 1), ('F', 'hr.gender_f', 2)) t(v, l, o)
  """

fn hr.contract_type_options() -> jsonb [stable]:
  return """
    select jsonb_agg(jsonb_build_object('value', v, 'label', l) order by o)
    from (values
      ('cdi', 'hr.contract_cdi', 1), ('cdd', 'hr.contract_cdd', 2),
      ('apprenticeship', 'hr.contract_apprenticeship', 3),
      ('internship', 'hr.contract_internship', 4), ('temp', 'hr.contract_temp', 5)
    ) t(v, l, o)
  """

fn hr.leave_type_options() -> jsonb [stable]:
  return """
    select jsonb_agg(jsonb_build_object('value', v, 'label', l) order by o)
    from (values
      ('paid_leave', 'hr.absence_paid_leave', 1), ('rtt', 'hr.absence_rtt', 2),
      ('sick', 'hr.absence_sick', 3), ('unpaid', 'hr.absence_unpaid', 4),
      ('training', 'hr.absence_training', 5), ('other', 'hr.absence_other', 6)
    ) t(v, l, o)
  """

-- Employee activate/deactivate (boolean toggle, not state machine)

fn hr.employee_deactivate(p_id text) -> jsonb [definer]:
  """
    update hr.employee set status = 'inactive', updated_at = now()
    where id = p_id::int and tenant_id = current_setting('app.tenant_id', true)
  """
  result := select to_jsonb(e) from hr.employee e where id = p_id::int
  return result

fn hr.employee_activate(p_id text) -> jsonb [definer]:
  """
    update hr.employee set status = 'active', updated_at = now()
    where id = p_id::int and tenant_id = current_setting('app.tenant_id', true)
  """
  result := select to_jsonb(e) from hr.employee e where id = p_id::int
  return result

-- Leave request reject/cancel (branches hors state machine)

fn hr.leave_request_reject(p_id text) -> jsonb [definer]:
  """
    update hr.leave_request set status = 'rejected'
    where id = p_id::int and status = 'pending'
      and tenant_id = current_setting('app.tenant_id', true)
  """
  result := select to_jsonb(r) from hr.leave_request r where id = p_id::int
  return result

fn hr.leave_request_cancel(p_id text) -> jsonb [definer]:
  """
    update hr.leave_request set status = 'cancelled'
    where id = p_id::int and status = 'pending'
      and tenant_id = current_setting('app.tenant_id', true)
  """
  result := select to_jsonb(r) from hr.leave_request r where id = p_id::int
  return result

-- Employee read strategy (enriched with stats)

fn hr._employee_read_query(p_id text) -> jsonb [stable]:
  return """
    select to_jsonb(e) || jsonb_build_object(
      'display_name', e.first_name || ' ' || e.last_name,
      'cp_remaining', coalesce((select allocated - used from hr.leave_balance where employee_id = e.id and leave_type = 'paid_leave'), 0),
      'rtt_remaining', coalesce((select allocated - used from hr.leave_balance where employee_id = e.id and leave_type = 'rtt'), 0),
      'hours_30d', coalesce((select sum(hours) from hr.timesheet where employee_id = e.id and work_date >= current_date - 30), 0),
      'leave_count', (select count(*) from hr.leave_request where employee_id = e.id)::int
    )
    from hr.employee e
    where e.id = p_id::int and e.tenant_id = current_setting('app.tenant_id', true)
  """

fn hr._employee_list_query(p_filter text?) -> setof jsonb [stable]:
  return """
    select to_jsonb(e) || jsonb_build_object(
      'display_name', e.first_name || ' ' || e.last_name
    )
    from hr.employee e
    where e.tenant_id = current_setting('app.tenant_id', true)
      and (p_filter is null or p_filter = ''
           or e.last_name ilike '%' || p_filter || '%'
           or e.first_name ilike '%' || p_filter || '%'
           or e.employee_code ilike '%' || p_filter || '%')
    order by e.last_name, e.first_name
  """

-- Leave read strategy (enriched with employee name + balance)

fn hr._leave_read_query(p_id text) -> jsonb [stable]:
  return """
    select to_jsonb(r) || jsonb_build_object(
      'employee_name', e.first_name || ' ' || e.last_name,
      'balance_remaining', coalesce(b.allocated - b.used, 0)
    )
    from hr.leave_request r
    join hr.employee e on e.id = r.employee_id
    left join hr.leave_balance b on b.employee_id = r.employee_id and b.leave_type = r.leave_type
    where r.id = p_id::int and r.tenant_id = current_setting('app.tenant_id', true)
  """

fn hr._leave_list_query(p_filter text?) -> setof jsonb [stable]:
  return """
    select to_jsonb(r) || jsonb_build_object(
      'employee_name', e.first_name || ' ' || e.last_name
    )
    from hr.leave_request r
    join hr.employee e on e.id = r.employee_id
    where r.tenant_id = current_setting('app.tenant_id', true)
      and (p_filter is null or p_filter = ''
           or e.last_name ilike '%' || p_filter || '%'
           or e.first_name ilike '%' || p_filter || '%')
    order by r.start_date desc
  """
