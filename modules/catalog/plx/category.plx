entity catalog.category:
  table: catalog.category
  uri: 'catalog://category'
  label: 'catalog.entity_category'
  list_order: 'sort_order, name'

  fields:
    name text required
    parent_id int? ref(catalog.category)
    sort_order int default(0)

  strategies:
    read.query: catalog._category_read_query
    read.hateoas: catalog._category_hateoas

  view:
    compact: [name, sort_order]
    standard:
      fields: [name, sort_order]
      stats:
        {key: article_count, label: catalog.stat_article_count}
        {key: children_count, label: catalog.stat_children_count}
    expanded:
      fields: [name, sort_order, created_at]
      stats:
        {key: article_count, label: catalog.stat_article_count}
        {key: children_count, label: catalog.stat_children_count}
    form:
      'catalog.section_category':
        {key: name, type: text, label: catalog.field_name, required: true}
        {key: parent_id, type: select, label: catalog.field_parent, search: true, options: {source: 'catalog://category', display: name}}
        {key: sort_order, type: number, label: catalog.field_sort_order}

  actions:
    edit:   {label: catalog.action_edit, variant: muted}
    delete: {label: catalog.action_delete, variant: danger, confirm: catalog.confirm_delete_category}
