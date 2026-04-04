fn crm.type_options() -> jsonb [stable]:
  return """
    select jsonb_agg(jsonb_build_object('value', v, 'label', l) order by o)
    from (values
      ('individual', 'crm.type_individual', 1),
      ('company',    'crm.type_company',    2)
    ) t(v, l, o)
  """

fn crm.tier_options() -> jsonb [stable]:
  return """
    select jsonb_agg(jsonb_build_object('value', v, 'label', l) order by o)
    from (values
      ('standard', 'crm.tier_standard', 1),
      ('premium',  'crm.tier_premium',  2),
      ('vip',      'crm.tier_vip',      3)
    ) t(v, l, o)
  """

fn crm.display_name(p_name text, p_type text, p_city text?) -> text [stable]:
  if p_type = 'company' and p_city is not null:
    return p_name || ' (' || p_city || ')'
  return p_name

fn crm.tier_variant(p_tier text) -> text [stable]:
  return case p_tier
    when 'vip' then 'warning'
    when 'premium' then 'primary'
    else 'default'
  end

fn crm.type_label(p_type text) -> text [stable]:
  return case p_type
    when 'individual' then i18n.t('crm.type_individual')
    when 'company'    then i18n.t('crm.type_company')
    when 'call'       then i18n.t('crm.type_call')
    when 'visit'      then i18n.t('crm.type_visit')
    when 'email'      then i18n.t('crm.type_email')
    when 'note'       then i18n.t('crm.type_note')
    else p_type
  end
