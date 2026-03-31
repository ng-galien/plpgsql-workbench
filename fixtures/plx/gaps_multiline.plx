-- Gap 3: Multi-line function calls (parens spanning lines)

fn test.nav_items() -> jsonb [stable]:
  return jsonb_build_array(
    jsonb_build_object('href', '/', 'label', 'Home'),
    jsonb_build_object('href', '/items', 'label', 'Items')
  )

fn test.view_def() -> jsonb [stable]:
  return jsonb_build_object(
    'uri', 'test://item',
    'label', 'test.entity_item',
    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('name', 'status')
      )
    )
  )

fn test.multi_arg(p_a int, p_b int) -> jsonb:
  result := jsonb_build_object(
    'sum', p_a + p_b,
    'product', p_a * p_b
  )
  return result
