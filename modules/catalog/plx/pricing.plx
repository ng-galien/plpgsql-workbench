entity catalog.pricing_tier:
  table: catalog.pricing_tier
  uri: 'catalog://pricing_tier'
  label: 'catalog.entity_pricing_tier'
  expose: false

  fields:
    article_id int required ref(catalog.article)
    min_qty numeric required
    unit_price numeric required

  indexes:
    by_article_qty:
      on: [article_id, min_qty]
