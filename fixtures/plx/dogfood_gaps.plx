-- Test the 4 gaps: attributes, typed defaults, subquery assign, SQL triple quotes

-- Gap 1: Function attributes [definer], [stable]
fn expense.category_create(p_row expense.category) -> jsonb [definer]:
  result := insert into expense.category (name, accounting_code)
    values (p_row.name, p_row.accounting_code)
    returning *
  return to_jsonb(result)

fn expense.category_view() -> jsonb [stable]:
  return {uri: 'expense://category', label: 'expense.entity_category'}

-- Gap 2: Default params with null
fn expense.category_list(p_filter text? = null) -> setof jsonb [stable]:
  if p_filter = null:
    return """
      select to_jsonb(c)
      from expense.category c
      order by c.name
    """
  else:
    raise 'expense.err_dynamic_filter_not_supported'

-- Gap 3: Subquery assignment
fn expense.category_read(p_id text) -> jsonb [stable]:
  result := (select to_jsonb(c) from expense.category c where c.id = p_id::int)
  if result = null:
    return null
  return result

-- Gap 4: SQL multi-line return
fn expense.expense_report_list(p_filter text? = null) -> setof jsonb [stable]:
  if p_filter = null:
    return """
      select to_jsonb(r)
      from expense.expense_report r
      order by r.updated_at desc
    """
  else:
    raise 'expense.err_dynamic_filter_not_supported'

-- Combined: definer + stable
fn expense.brand() -> text [stable]:
  return pgv.t('expense.brand')
