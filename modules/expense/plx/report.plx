entity expense.expense_report:
  table: expense.expense_report
  uri: 'expense://expense_report'
  icon: 'receipt'
  label: 'expense.entity_expense_report'
  list_order: 'updated_at desc'

  fields:
    reference text? unique
    author text required
    start_date date required
    end_date date required
    status text default('draft')
    comment text?

  validate:
    status_valid: """
      coalesce(p_input->>'status', 'draft') in ('draft', 'submitted', 'validated', 'reimbursed', 'rejected')
    """
    date_order: """
      (p_input->>'end_date')::date >= (p_input->>'start_date')::date
    """

  states draft -> submitted -> validated -> reimbursed:
    submit(draft -> submitted)
    validate(submitted -> validated)
    reimburse(validated -> reimbursed)

  view:
    compact: [reference, author, status]
    standard:
      fields: [reference, author, start_date, end_date, status, comment]
      stats:
        {key: line_count, label: expense.stat_line_count}
        {key: total_excl_tax, label: expense.stat_total_excl_tax}
        {key: total_incl_tax, label: expense.stat_total_incl_tax}
      related:
        {entity: 'ledger://journal_entry', filter: 'expense_note_id={id}', label: expense.stat_total}
    expanded:
      fields: [reference, author, start_date, end_date, status, comment, created_at, updated_at]
      stats:
        {key: line_count, label: expense.stat_line_count}
        {key: total_excl_tax, label: expense.stat_total_excl_tax}
        {key: total_incl_tax, label: expense.stat_total_incl_tax}
      related:
        {entity: 'ledger://journal_entry', filter: 'expense_note_id={id}', label: expense.stat_total}
    form:
      'expense.section_info':
        {key: author, type: text, label: expense.field_author, required: true}
        {key: start_date, type: date, label: expense.field_start_date, required: true}
        {key: end_date, type: date, label: expense.field_end_date, required: true}
        {key: comment, type: textarea, label: expense.field_comment}

  strategies:
    read.query: expense._report_read_query
    read.hateoas: expense._report_hateoas
    list.query: expense._report_list_query

  before create:
    if p_row.reference is null:
      p_row := jsonb_populate_record(p_row, jsonb_build_object('reference', expense._next_reference()))

  actions:
    edit:      {label: expense.action_edit, variant: muted}
    add_line:  {label: expense.action_add_line, variant: primary}
    submit:    {label: expense.action_submit, variant: primary, confirm: expense.confirm_submit}
    validate:  {label: expense.action_validate, variant: primary, confirm: expense.confirm_validate}
    reject:    {label: expense.action_reject, variant: danger, confirm: expense.confirm_reject}
    reimburse: {label: expense.action_reimburse, variant: primary, confirm: expense.confirm_reimburse}
    delete:    {label: expense.action_delete, variant: danger, confirm: expense.confirm_delete}
