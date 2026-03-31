-- Edge cases corpus for PLX compiler hardening

-- 1. No params, no DECLARE needed
fn pgv.noop() -> void:
  return

-- 2. Multiple params with defaults
fn crm.client_list(p_limit int, p_offset int, p_status text) -> setof jsonb:
  for row in select * from crm.client where status = p_status order by name limit p_limit offset p_offset:
    yield {id: row.id, name: row.name}

-- 3. Nested if/elsif/else
fn crm.tier_label(p_tier text) -> text:
  if p_tier = 'gold':
    return 'Gold'
  elsif p_tier = 'silver':
    return 'Silver'
  elsif p_tier = 'bronze':
    return 'Bronze'
  else:
    return 'Standard'

-- 4. Empty JSON and empty array
fn crm.empty_structures() -> jsonb:
  obj := {}
  arr := []
  return {obj, arr}

-- 5. String with apostrophes
fn crm.greeting() -> text:
  return 'C''est l''heure du déjeuner'

-- 6. Scalar select (no FROM)
fn pgv.get_version() -> int:
  v := select 1
  return v

-- 7. Select single column
fn crm.client_name(p_id int) -> text:
  name := select name from crm.client where id = p_id
    else raise 'not_found'
  return name

-- 8. Multiple functions accessing same schema
fn crm.client_count() -> int:
  n := select count(*) from crm.client
  return n

-- 9. Complex interpolation
fn crm.format_address(p_id int) -> text:
  row := select * from crm.client where id = p_id
    else raise 'not_found'
  return "#{row.name} - #{row.city} (#{row.postal_code})"

-- 10. Schema-qualified call in expression
fn crm.client_slug(p_id int) -> text:
  row := select * from crm.client where id = p_id
    else raise 'not_found'
  slug := pgv.slugify(row.name)
  return slug

-- 11. Standalone SQL (update without assignment)
fn crm.client_touch(p_id int) -> void:
  update crm.client set updated_at = now() where id = p_id
  return

-- 12. NOT and nullable check
fn crm.validate_client(p_id int) -> jsonb:
  row := select * from crm.client where id = p_id
    else raise 'not_found'
  if not row.email?:
    raise 'email_required'
  return {valid: true}
