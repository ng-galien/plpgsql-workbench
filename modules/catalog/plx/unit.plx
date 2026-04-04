entity catalog.unit:
  table: catalog.unit
  uri: 'catalog://unit'
  label: 'catalog.entity_unit'
  expose: false

  fields:
    name text required unique
    symbol text?
