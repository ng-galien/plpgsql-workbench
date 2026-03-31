-- Gap 1: :: type cast operator

fn test.cast_basic(p_id text) -> int:
  result := p_id::int
  return result

fn test.cast_in_expr(p_id text) -> jsonb:
  row := select * from test.item where id = p_id::int
    else raise 'not_found'
  return to_jsonb(row)

fn test.cast_chain() -> text:
  result := select extract(year from now())::int::text
  return result

fn test.cast_in_return(p_val int) -> text:
  return p_val::text
