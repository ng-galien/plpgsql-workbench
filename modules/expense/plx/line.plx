entity expense.line:
  table: expense.line
  uri: 'expense://line'
  label: 'expense.entity_line'
  expose: false

  fields:
    note_id int ref(expense.expense_report)
    expense_date date required
    category_id int? ref(expense.category)
    description text required
    amount_excl_tax numeric required
    vat numeric default(0)
    receipt text?
    km numeric?

  generated:
    amount_incl_tax numeric(12,2): amount_excl_tax + vat

  indexes:
    line_date:
      on: [expense_date]
