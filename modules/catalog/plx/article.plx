entity catalog.article uses auditable:
  table: catalog.article
  uri: 'catalog://article'
  label: 'catalog.entity_article'
  list_order: 'name'

  fields:
    reference text? unique
    name text required
    description text?
    category_id int? ref(catalog.category)
    unit_id int? ref(catalog.unit)
    sale_price numeric default(0)
    purchase_price numeric default(0)
    vat_rate numeric default(20)
    barcode text? unique
    image_id int?
    weight numeric?
    min_order_qty numeric default(1)
    active boolean default(true)

  validate:
    sale_price_positive: coalesce((p_input->>'sale_price')::numeric, 0) >= 0
    purchase_price_positive: coalesce((p_input->>'purchase_price')::numeric, 0) >= 0
    vat_rate_valid: """
      coalesce((p_input->>'vat_rate')::numeric, 20) in (0, 2.1, 5.5, 10, 20)
    """

  strategies:
    read.query: catalog._article_read_query
    list.query: catalog._article_list_query

  view:
    compact: [name, reference, sale_price, active]
    standard:
      fields: [name, reference, category_id, unit, sale_price, purchase_price, vat_rate, active]
      stats:
        {key: supplier_count, label: catalog.stat_supplier_count}
      related:
        {entity: 'quote://line_item', filter: 'article_id={id}', label: catalog.related_quotes}
        {entity: 'purchase://order_line', filter: 'article_id={id}', label: catalog.related_purchases}
    expanded:
      fields: [name, reference, description, category_id, unit, sale_price, purchase_price, vat_rate, barcode, weight, min_order_qty, active, created_at, updated_at]
      stats:
        {key: supplier_count, label: catalog.stat_supplier_count}
      related:
        {entity: 'quote://line_item', filter: 'article_id={id}', label: catalog.related_quotes}
        {entity: 'purchase://order_line', filter: 'article_id={id}', label: catalog.related_purchases}
    form:
      'catalog.section_identity':
        {key: reference, type: text, label: catalog.field_reference}
        {key: name, type: text, label: catalog.field_name, required: true}
        {key: description, type: textarea, label: catalog.field_description}
        {key: barcode, type: text, label: catalog.field_barcode}
      'catalog.section_classification':
        {key: category_id, type: select, label: catalog.field_category, search: true, options: {source: 'catalog://category', display: name}}
        {key: unit, type: select, label: catalog.field_unit, options: catalog.unit_options}
        {key: image_id, type: select, label: catalog.field_image, search: true, options: {source: 'asset://asset', display: title}}
      'catalog.section_pricing':
        {key: sale_price, type: number, label: catalog.field_sale_price, required: true}
        {key: purchase_price, type: number, label: catalog.field_purchase_price}
        {key: vat_rate, type: select, label: catalog.field_vat_rate, options: catalog.vat_options}
      'catalog.section_logistics':
        {key: weight, type: number, label: catalog.field_weight}
        {key: min_order_qty, type: number, label: catalog.field_min_order_qty}

  actions:
    edit:       {label: catalog.action_edit, variant: muted}
    deactivate: {label: catalog.action_deactivate, variant: warning}
    activate:   {label: catalog.action_activate}
    delete:     {label: catalog.action_delete, variant: danger, confirm: catalog.confirm_delete_article}
