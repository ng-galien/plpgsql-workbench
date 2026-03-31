-- Gap 2: CASE as inline expression

fn test.status_label(p_status text) -> text [stable]:
  return case p_status
    when 'draft' then 'Draft'
    when 'active' then 'Active'
    else 'Unknown'
  end

fn test.badge(p_status text) -> text [stable]:
  return pgv.badge(
    case p_status when 'draft' then 'Brouillon' when 'active' then 'Actif' else p_status end,
    case p_status when 'draft' then 'secondary' when 'active' then 'success' else 'muted' end
  )

fn test.case_assign(p_val int) -> text:
  label := case p_val when 1 then 'one' when 2 then 'two' else 'other' end
  return label
