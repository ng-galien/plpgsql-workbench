entity asset.asset uses auditable:
  table: asset.asset
  uri: 'asset://asset'
  label: 'asset.entity_asset'
  list_order: 'created_at desc'

  fields:
    path text required
    filename text required
    mime_type text default('image/jpeg')
    status text default('to_classify')
    width int?
    height int?
    orientation text?
    title text?
    description text?
    tags text[] default('{}')
    credit text?
    season text?
    usage_hint text?
    colors text[] default('{}')
    thumb_path text?
    classified_at timestamptz?

  validate:
    mime_valid: """
      coalesce(p_input->>'mime_type', 'image/jpeg') in ('image/jpeg', 'image/png', 'image/svg+xml')
    """
    status_valid: """
      coalesce(p_input->>'status', 'to_classify') in ('to_classify', 'classified', 'archived')
    """

  states to_classify -> classified -> archived:
    classify(to_classify -> classified)
    archive(classified -> archived)
    restore(archived -> classified)

  view:
    compact: [title, mime_type, status]
    standard:
      fields: [title, filename, mime_type, status, orientation, tags]
      stats:
        {key: width, label: asset.field_width}
        {key: height, label: asset.field_height}
    expanded:
      fields: [title, description, filename, path, mime_type, status, orientation, tags, credit, season, usage_hint, colors, created_at, classified_at]
      stats:
        {key: width, label: asset.field_width}
        {key: height, label: asset.field_height}
    form:
      'asset.section_file':
        {key: path, type: text, label: asset.field_path, required: true}
        {key: filename, type: text, label: asset.field_filename, required: true}
        {key: mime_type, type: select, label: asset.field_mime, options: asset.mime_options}
      'asset.section_metadata':
        {key: title, type: text, label: asset.field_title}
        {key: description, type: textarea, label: asset.field_description}
        {key: credit, type: text, label: asset.field_credit}
        {key: usage_hint, type: text, label: asset.field_usage_hint}
      'asset.section_classification':
        {key: tags, type: text, label: asset.field_tags}
        {key: season, type: select, label: asset.field_season, options: asset.season_options}
        {key: orientation, type: select, label: asset.field_orientation, options: asset.orientation_options}

  actions:
    classify: {label: asset.action_classify, variant: primary}
    edit:     {label: asset.action_edit}
    archive:  {label: asset.action_archive, variant: warning, confirm: asset.confirm_archive}
    restore:  {label: asset.action_restore}
    delete:   {label: asset.action_delete, variant: danger, confirm: asset.confirm_delete}
