fn expense._next_reference() -> text:
  return """
    select 'NDF-' || extract(year from now())::text || '-' ||
      lpad((coalesce(
        max(substring(reference from 'NDF-' || extract(year from now())::text || '-(\d+)')::int),
        0
      ) + 1)::text, 3, '0')
    from expense.expense_report
    where reference like 'NDF-' || extract(year from now())::text || '-%'
  """

fn expense._report_read_query(p_id text) -> jsonb [stable]:
  return """
    select to_jsonb(r) || jsonb_build_object(
      'lines', coalesce((
        select jsonb_agg(to_jsonb(lg) || jsonb_build_object('category_name', c.name) order by lg.expense_date)
        from expense.line lg
        left join expense.category c on c.id = lg.category_id
        where lg.note_id = r.id
      ), '[]'::jsonb),
      'total_excl_tax', coalesce((select sum(amount_excl_tax) from expense.line where note_id = r.id), 0),
      'total_incl_tax', coalesce((select sum(amount_incl_tax) from expense.line where note_id = r.id), 0),
      'line_count', (select count(*) from expense.line where note_id = r.id)::int
    )
    from expense.expense_report r
    where r.id = p_id::int or r.reference = p_id
  """

fn expense._report_hateoas(p_result jsonb) -> jsonb [stable]:
  return """
    select case p_result->>'status'
      when 'draft' then (
        jsonb_build_array(
          jsonb_build_object('method', 'edit', 'uri', 'expense://expense_report/' || (p_result->>'id') || '/edit'),
          jsonb_build_object('method', 'add_line', 'uri', 'expense://expense_report/' || (p_result->>'id') || '/add_line')
        )
        || case when (p_result->>'line_count')::int > 0 then
          jsonb_build_array(jsonb_build_object('method', 'submit', 'uri', 'expense://expense_report/' || (p_result->>'id') || '/submit'))
        else '[]'::jsonb end
        || jsonb_build_array(jsonb_build_object('method', 'delete', 'uri', 'expense://expense_report/' || (p_result->>'id')))
      )
      when 'submitted' then jsonb_build_array(
        jsonb_build_object('method', 'validate', 'uri', 'expense://expense_report/' || (p_result->>'id') || '/validate'),
        jsonb_build_object('method', 'reject', 'uri', 'expense://expense_report/' || (p_result->>'id') || '/reject')
      )
      when 'validated' then jsonb_build_array(
        jsonb_build_object('method', 'reimburse', 'uri', 'expense://expense_report/' || (p_result->>'id') || '/reimburse')
      )
      else '[]'::jsonb
    end
  """

fn expense._report_list_query(p_filter text?) -> setof jsonb [stable]:
  return """
    select to_jsonb(r) || jsonb_build_object(
      'line_count', coalesce(agg.cnt, 0),
      'total_excl_tax', coalesce(agg.total_ht, 0),
      'total_incl_tax', coalesce(agg.total_ttc, 0)
    )
    from expense.expense_report r
    left join lateral (
      select count(*) as cnt,
             sum(amount_excl_tax) as total_ht,
             sum(amount_incl_tax) as total_ttc
      from expense.line where note_id = r.id
    ) agg on true
    where r.tenant_id = current_setting('app.tenant_id', true)
    order by r.updated_at desc
  """

fn expense.status_options() -> jsonb [stable]:
  return """
    select jsonb_agg(jsonb_build_object('value', v, 'label', l) order by o)
    from (values
      ('draft',      'expense.status_draft',      1),
      ('submitted',  'expense.status_submitted',  2),
      ('validated',  'expense.status_validated',  3),
      ('reimbursed', 'expense.status_reimbursed', 4),
      ('rejected',   'expense.status_rejected',   5)
    ) t(v, l, o)
  """
