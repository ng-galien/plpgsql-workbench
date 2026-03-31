-- expense module — full dog-food in PLX

import jsonb_build_object as obj
import jsonb_build_array as arr
import pgv.t as t
import pgv.badge as badge

fn expense._next_reference() -> text:
  yr := select extract(year from now())::text
  mx := (select max(substring(reference from 'NDF-' || v_yr || '-(\d+)')::int)
    from expense.expense_report
    where reference like 'NDF-' || v_yr || '-%')
  result := (select 'NDF-' || v_yr || '-' || lpad((coalesce(v_mx, 0) + 1)::text, 3, '0'))
  return result

fn expense._status_badge(p_status text) -> text [stable]:
  return badge(
    case p_status
      when 'draft' then t('expense.status_draft')
      when 'submitted' then t('expense.status_submitted')
      when 'validated' then t('expense.status_validated')
      when 'reimbursed' then t('expense.status_reimbursed')
      when 'rejected' then t('expense.status_rejected')
      else p_status
    end,
    case p_status
      when 'draft' then 'secondary'
      when 'submitted' then 'warning'
      when 'validated' then 'info'
      when 'reimbursed' then 'success'
      when 'rejected' then 'danger'
      else 'secondary'
    end
  )

fn expense.brand() -> text [stable]:
  return t('expense.brand')

fn expense.nav_items() -> jsonb [stable]:
  return arr(
    obj('href', '/', 'label', t('expense.nav_dashboard'), 'icon', 'home'),
    obj('href', '/expense_reports', 'label', t('expense.nav_reports'), 'icon', 'file-text', 'entity', 'expense_report', 'uri', 'expense://expense_report'),
    obj('href', '/categories', 'label', t('expense.nav_categories'), 'icon', 'tag', 'entity', 'category', 'uri', 'expense://category')
  )

-- Category CRUD

fn expense.category_view() -> jsonb [stable]:
  return obj(
    'uri', 'expense://category', 'icon', '🏷', 'label', 'expense.entity_category',
    'template', obj(
      'compact', obj('fields', arr('name', 'accounting_code')),
      'standard', obj('fields', arr('name', 'accounting_code')),
      'expanded', obj('fields', arr('name', 'accounting_code', 'created_at')),
      'form', obj('sections', arr(
        obj('label', 'expense.section_info', 'fields', arr(
          obj('key', 'name', 'type', 'text', 'label', 'expense.field_name', 'required', true),
          obj('key', 'accounting_code', 'type', 'text', 'label', 'expense.field_accounting_code')
        ))
      ))
    ),
    'actions', obj(
      'edit', obj('label', 'expense.action_edit', 'icon', '✏', 'variant', 'muted'),
      'delete', obj('label', 'expense.action_delete', 'icon', '×', 'variant', 'danger', 'confirm', 'expense.confirm_delete_category')
    )
  )

fn expense.category_list(p_filter text? = null) -> setof jsonb [stable]:
  if p_filter = null:
    return query select to_jsonb(c) from expense.category c order by c.name
  else:
    return execute 'SELECT to_jsonb(c) FROM expense.category c WHERE ' || pgv.rsql_to_where(p_filter, 'expense', 'category') || ' ORDER BY c.name'

fn expense.category_read(p_id text) -> jsonb [stable]:
  result := (select to_jsonb(c) from expense.category c where c.id = p_id::int)
  if result = null:
    return null
  return result || obj('actions', arr(
    obj('method', 'edit', 'uri', 'expense://category/' || (result->>'id') || '/edit'),
    obj('method', 'delete', 'uri', 'expense://category/' || (result->>'id') || '/delete')
  ))

fn expense.category_create(p_row expense.category) -> jsonb [definer]:
  result := insert into expense.category (name, accounting_code)
    values (p_row.name, p_row.accounting_code)
    returning *
  return to_jsonb(result)

fn expense.category_update(p_row expense.category) -> jsonb [definer]:
  result := update expense.category set name = coalesce(p_row.name, name), accounting_code = coalesce(p_row.accounting_code, accounting_code)
    where id = p_row.id
    returning *
  return to_jsonb(result)

fn expense.category_delete(p_id text) -> jsonb [definer]:
  result := delete from expense.category where id = p_id::int
    returning *
  return to_jsonb(result)

-- Expense Report CRUD

fn expense.expense_report_view() -> jsonb [stable]:
  return obj(
    'uri', 'expense://expense_report', 'icon', '📋', 'label', 'expense.entity_expense_report',
    'template', obj(
      'compact', obj('fields', arr('reference', 'author', 'status', 'total_incl_tax')),
      'standard', obj(
        'fields', arr('reference', 'author', 'start_date', 'end_date', 'status', 'comment'),
        'stats', arr(
          obj('key', 'line_count', 'label', 'expense.stat_line_count'),
          obj('key', 'total_excl_tax', 'label', 'expense.stat_total_excl_tax'),
          obj('key', 'total_incl_tax', 'label', 'expense.stat_total_incl_tax')
        ),
        'related', arr(
          obj('entity', 'ledger://journal_entry', 'label', 'expense.stat_total', 'filter', 'expense_note_id={id}')
        )
      ),
      'expanded', obj(
        'fields', arr('reference', 'author', 'start_date', 'end_date', 'status', 'comment', 'created_at', 'updated_at'),
        'stats', arr(
          obj('key', 'line_count', 'label', 'expense.stat_line_count'),
          obj('key', 'total_excl_tax', 'label', 'expense.stat_total_excl_tax'),
          obj('key', 'total_incl_tax', 'label', 'expense.stat_total_incl_tax')
        ),
        'related', arr(
          obj('entity', 'ledger://journal_entry', 'label', 'expense.stat_total', 'filter', 'expense_note_id={id}')
        )
      ),
      'form', obj('sections', arr(
        obj('label', 'expense.section_info', 'fields', arr(
          obj('key', 'author', 'type', 'text', 'label', 'expense.field_author', 'required', true),
          obj('key', 'start_date', 'type', 'date', 'label', 'expense.field_start_date', 'required', true),
          obj('key', 'end_date', 'type', 'date', 'label', 'expense.field_end_date', 'required', true),
          obj('key', 'comment', 'type', 'textarea', 'label', 'expense.field_comment')
        ))
      ))
    ),
    'actions', obj(
      'edit', obj('label', 'expense.action_edit', 'icon', '✏', 'variant', 'muted'),
      'add_line', obj('label', 'expense.action_add_line', 'icon', '+', 'variant', 'primary'),
      'submit', obj('label', 'expense.action_submit', 'icon', '→', 'variant', 'primary', 'confirm', 'expense.confirm_submit'),
      'validate', obj('label', 'expense.action_validate', 'icon', '✓', 'variant', 'primary', 'confirm', 'expense.confirm_validate'),
      'reject', obj('label', 'expense.action_reject', 'icon', '✗', 'variant', 'danger', 'confirm', 'expense.confirm_reject'),
      'reimburse', obj('label', 'expense.action_reimburse', 'icon', '€', 'variant', 'primary', 'confirm', 'expense.confirm_reimburse'),
      'delete', obj('label', 'expense.action_delete', 'icon', '×', 'variant', 'danger', 'confirm', 'expense.confirm_delete')
    )
  )

fn expense.expense_report_list(p_filter text? = null) -> setof jsonb [stable]:
  if p_filter = null:
    return query select to_jsonb(r) || jsonb_build_object(
        'line_count', coalesce(l.cnt, 0),
        'total_excl_tax', coalesce(l.sum_excl, 0),
        'total_incl_tax', coalesce(l.sum_incl, 0)
      )
      from expense.expense_report r
      left join lateral (
        select count(*) as cnt, sum(amount_excl_tax) as sum_excl, sum(amount_incl_tax) as sum_incl
        from expense.line where note_id = r.id
      ) l on true
      order by r.updated_at desc
  else:
    return execute 'SELECT to_jsonb(r) || jsonb_build_object(''line_count'', COALESCE(l.cnt, 0), ''total_excl_tax'', COALESCE(l.sum_excl, 0), ''total_incl_tax'', COALESCE(l.sum_incl, 0)) FROM expense.expense_report r LEFT JOIN LATERAL (SELECT count(*) as cnt, sum(amount_excl_tax) as sum_excl, sum(amount_incl_tax) as sum_incl FROM expense.line WHERE note_id = r.id) l ON true WHERE ' || pgv.rsql_to_where(p_filter, 'expense', 'expense_report') || ' ORDER BY r.updated_at DESC'

fn expense.expense_report_read(p_id text) -> jsonb [stable]:
  result := (select to_jsonb(r) || jsonb_build_object(
      'lines', coalesce((
        select jsonb_agg(to_jsonb(lg) || jsonb_build_object('category_name', c.name) order by lg.expense_date)
        from expense.line lg
        left join expense.category c on c.id = lg.category_id
        where lg.note_id = r.id
      ), '[]'::jsonb),
      'total_excl_tax', coalesce((select sum(amount_excl_tax) from expense.line where note_id = r.id), 0),
      'total_incl_tax', coalesce((select sum(amount_incl_tax) from expense.line where note_id = r.id), 0),
      'line_count', (select count(*) from expense.line where note_id = r.id)::int
    )
    from expense.expense_report r
    where r.id = p_id::int or r.reference = p_id
  )
  if result = null:
    return null
  status := result->>'status'
  id := (result->>'id')::int
  line_count := (result->>'line_count')::int
  actions := '[]'::jsonb
  match status:
    'draft':
      actions := arr(
        obj('method', 'edit', 'uri', 'expense://expense_report/' || id || '/edit'),
        obj('method', 'add_line', 'uri', 'expense://expense_report/' || id || '/add_line')
      )
      if line_count > 0:
        actions := actions || arr(obj('method', 'submit', 'uri', 'expense://expense_report/' || id || '/submit'))
      actions := actions || arr(obj('method', 'delete', 'uri', 'expense://expense_report/' || id || '/delete'))
    'submitted':
      actions := arr(
        obj('method', 'validate', 'uri', 'expense://expense_report/' || id || '/validate'),
        obj('method', 'reject', 'uri', 'expense://expense_report/' || id || '/reject')
      )
    'validated':
      actions := arr(obj('method', 'reimburse', 'uri', 'expense://expense_report/' || id || '/reimburse'))
    else:
      actions := '[]'::jsonb
  return result || obj('actions', actions)

fn expense.expense_report_create(p_row expense.expense_report) -> jsonb [definer]:
  ref := expense._next_reference()
  result := insert into expense.expense_report (reference, author, start_date, end_date, comment)
    values (ref, p_row.author, p_row.start_date, p_row.end_date, p_row.comment)
    returning *
  return to_jsonb(result)

fn expense.expense_report_update(p_row expense.expense_report) -> jsonb [definer]:
  result := update expense.expense_report set
    author = coalesce(p_row.author, author),
    start_date = coalesce(p_row.start_date, start_date),
    end_date = coalesce(p_row.end_date, end_date),
    comment = coalesce(p_row.comment, comment),
    updated_at = now()
    where id = p_row.id and status = 'draft'
    returning *
  return to_jsonb(result)

fn expense.expense_report_delete(p_id text) -> jsonb [definer]:
  result := delete from expense.expense_report
    where (id = p_id::int or reference = p_id) and status = 'draft'
    returning *
  return to_jsonb(result)

-- i18n seed (SQL passthrough)
fn expense.i18n_seed() -> void:
  insert into pgv.i18n (lang, key, value) values
    ('fr', 'expense.brand', 'Notes de frais'),
    ('fr', 'expense.nav_dashboard', 'Dashboard'),
    ('fr', 'expense.nav_reports', 'Notes'),
    ('fr', 'expense.nav_categories', 'Catégories'),
    ('fr', 'expense.entity_expense_report', 'Note de frais'),
    ('fr', 'expense.entity_category', 'Catégorie de frais'),
    ('fr', 'expense.section_info', 'Informations'),
    ('fr', 'expense.section_lines', 'Lignes de dépenses'),
    ('fr', 'expense.status_draft', 'Brouillon'),
    ('fr', 'expense.status_submitted', 'Soumise'),
    ('fr', 'expense.status_validated', 'Validée'),
    ('fr', 'expense.status_reimbursed', 'Remboursée'),
    ('fr', 'expense.status_rejected', 'Rejetée'),
    ('fr', 'expense.stat_reports', 'Notes de frais'),
    ('fr', 'expense.stat_current_total', 'Total en cours'),
    ('fr', 'expense.stat_avg_amount', 'Montant moyen'),
    ('fr', 'expense.stat_pending_validation', 'A valider'),
    ('fr', 'expense.stat_total_excl_tax', 'Total HT'),
    ('fr', 'expense.stat_total_vat', 'Total TVA'),
    ('fr', 'expense.stat_total_incl_tax', 'Total TTC'),
    ('fr', 'expense.stat_line_count', 'Lignes'),
    ('fr', 'expense.stat_total', 'Total'),
    ('fr', 'expense.col_reference', 'Référence'),
    ('fr', 'expense.col_author', 'Auteur'),
    ('fr', 'expense.col_period', 'Période'),
    ('fr', 'expense.col_lines', 'Lignes'),
    ('fr', 'expense.col_status', 'Statut'),
    ('fr', 'expense.col_total_incl_tax', 'Total TTC'),
    ('fr', 'expense.col_date', 'Date'),
    ('fr', 'expense.col_category', 'Catégorie'),
    ('fr', 'expense.col_description', 'Description'),
    ('fr', 'expense.col_km', 'Km'),
    ('fr', 'expense.col_excl_tax', 'HT'),
    ('fr', 'expense.col_vat', 'TVA'),
    ('fr', 'expense.col_incl_tax', 'TTC'),
    ('fr', 'expense.col_accounting_code', 'Code comptable'),
    ('fr', 'expense.col_start_date', 'Date début'),
    ('fr', 'expense.col_end_date', 'Date fin'),
    ('fr', 'expense.col_line_count', 'Nb lignes'),
    ('fr', 'expense.col_name', 'Nom'),
    ('fr', 'expense.field_author', 'Auteur'),
    ('fr', 'expense.field_start_date', 'Date début'),
    ('fr', 'expense.field_end_date', 'Date fin'),
    ('fr', 'expense.field_comment', 'Commentaire'),
    ('fr', 'expense.field_expense_date', 'Date'),
    ('fr', 'expense.field_category', 'Catégorie'),
    ('fr', 'expense.field_description', 'Description'),
    ('fr', 'expense.field_amount_excl_tax', 'Montant HT'),
    ('fr', 'expense.field_vat', 'TVA'),
    ('fr', 'expense.field_km', 'Km (si déplacement)'),
    ('fr', 'expense.field_status', 'Statut'),
    ('fr', 'expense.field_name', 'Nom'),
    ('fr', 'expense.field_accounting_code', 'Code comptable'),
    ('fr', 'expense.action_edit', 'Modifier'),
    ('fr', 'expense.action_delete', 'Supprimer'),
    ('fr', 'expense.action_submit', 'Soumettre'),
    ('fr', 'expense.action_validate', 'Valider'),
    ('fr', 'expense.action_reject', 'Rejeter'),
    ('fr', 'expense.action_reimburse', 'Rembourser'),
    ('fr', 'expense.action_add_line', 'Ajouter une ligne'),
    ('fr', 'expense.action_new_report', 'Nouvelle note'),
    ('fr', 'expense.confirm_submit', 'Soumettre cette note pour validation ?'),
    ('fr', 'expense.confirm_validate', 'Valider cette note de frais ?'),
    ('fr', 'expense.confirm_reject', 'Rejeter cette note de frais ?'),
    ('fr', 'expense.confirm_reimburse', 'Marquer cette note comme remboursée ?'),
    ('fr', 'expense.confirm_delete', 'Supprimer cette note de frais ?'),
    ('fr', 'expense.confirm_delete_category', 'Supprimer cette catégorie ?'),
    ('fr', 'expense.filter_all', 'Tous'),
    ('fr', 'expense.filter_draft', 'Brouillon'),
    ('fr', 'expense.filter_submitted', 'Soumise'),
    ('fr', 'expense.filter_validated', 'Validée'),
    ('fr', 'expense.filter_reimbursed', 'Remboursée'),
    ('fr', 'expense.filter_rejected', 'Rejetée'),
    ('fr', 'expense.empty_no_category', 'Aucune catégorie'),
    ('fr', 'expense.empty_no_report', 'Aucune note de frais'),
    ('fr', 'expense.empty_first_report', 'Créez votre première note pour commencer.'),
    ('fr', 'expense.empty_no_results', 'Aucune note trouvée'),
    ('fr', 'expense.empty_no_line', 'Aucune ligne'),
    ('fr', 'expense.empty_add_line', 'Ajoutez des dépenses à cette note.'),
    ('fr', 'expense.err_id_required', 'ID requis.'),
    ('fr', 'expense.err_fields_required', 'Auteur, date début et date fin sont requis.'),
    ('fr', 'expense.err_date_order', 'La date de fin doit être postérieure à la date de début.'),
    ('fr', 'expense.err_note_not_modifiable', 'Note introuvable ou non modifiable.'),
    ('fr', 'expense.err_line_fields', 'Note, date, description et montant HT requis.'),
    ('fr', 'expense.err_note_not_found', 'Note introuvable.'),
    ('fr', 'expense.err_not_draft', 'Ajout impossible : la note n''est plus en brouillon.'),
    ('fr', 'expense.err_no_lines', 'Impossible de soumettre une note sans ligne.'),
    ('fr', 'expense.err_not_draft_submit', 'Note introuvable ou pas en brouillon.'),
    ('fr', 'expense.err_not_submitted', 'Note introuvable ou pas en statut soumise.'),
    ('fr', 'expense.err_not_validated', 'Note introuvable ou pas en statut validée.'),
    ('fr', 'expense.toast_line_added', 'Ligne ajoutée.'),
    ('fr', 'expense.toast_note_created', 'Note créée.'),
    ('fr', 'expense.toast_note_updated', 'Note modifiée.'),
    ('fr', 'expense.toast_note_submitted', 'Note soumise pour validation.'),
    ('fr', 'expense.toast_note_validated', 'Note validée.'),
    ('fr', 'expense.toast_note_rejected', 'Note rejetée.'),
    ('fr', 'expense.toast_note_reimbursed', 'Note remboursée')
  on conflict do nothing
  return
