entity catalog.supplier_article:
  table: catalog.supplier_article
  uri: 'catalog://supplier_article'
  label: 'catalog.entity_supplier_article'
  list_order: 'supplier_name'

  fields:
    article_id int required ref(catalog.article)
    supplier_name text required
    supplier_ref text?
    cost_price numeric?
    lead_time_days int?
    moq int?
    is_preferred boolean default(false)

  indexes:
    by_article:
      on: [article_id]

  view:
    compact: [supplier_name, cost_price, is_preferred]
    standard:
      fields: [supplier_name, supplier_ref, cost_price, lead_time_days, moq, is_preferred]
    expanded:
      fields: [supplier_name, supplier_ref, cost_price, lead_time_days, moq, is_preferred, created_at]
    form:
      'catalog.section_supplier':
        {key: article_id, type: select, label: catalog.field_article, search: true, options: {source: 'catalog://article', display: name}, required: true}
        {key: supplier_name, type: text, label: catalog.field_supplier_name, required: true}
        {key: supplier_ref, type: text, label: catalog.field_supplier_ref}
        {key: cost_price, type: number, label: catalog.field_cost_price}
        {key: lead_time_days, type: number, label: catalog.field_lead_time}
        {key: moq, type: number, label: catalog.field_moq}
        {key: is_preferred, type: checkbox, label: catalog.field_preferred}

  actions:
    edit:   {label: catalog.action_edit, variant: muted}
    delete: {label: catalog.action_delete, variant: danger, confirm: catalog.confirm_delete_supplier}
