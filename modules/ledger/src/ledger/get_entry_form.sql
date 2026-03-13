CREATE OR REPLACE FUNCTION ledger.get_entry_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_entry record;
  v_body text;
  v_title text;
  v_date text;
  v_ref text;
  v_desc text;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO v_entry FROM ledger.journal_entry WHERE id = p_id;
    IF NOT FOUND THEN RETURN pgv.empty(pgv.t('ledger.empty_entry_not_found')); END IF;
    IF v_entry.posted THEN RETURN pgv.alert(pgv.t('ledger.err_posted_readonly'), 'danger'); END IF;
    v_title := pgv.t('ledger.btn_edit') || ' ' || v_entry.reference;
    v_date := to_char(v_entry.entry_date, 'YYYY-MM-DD');
    v_ref := pgv.esc(v_entry.reference);
    v_desc := pgv.esc(v_entry.description);
  ELSE
    v_title := pgv.t('ledger.title_new_entry');
    v_date := to_char(CURRENT_DATE, 'YYYY-MM-DD');
    v_ref := '';
    v_desc := '';
  END IF;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[
    pgv.t('ledger.nav_entries'), pgv.call_ref('get_entries'),
    v_title
  ]);

  v_body := v_body || pgv.form('post_entry_save',
    CASE WHEN p_id IS NOT NULL THEN '<input type="hidden" name="id" value="' || p_id || '">' ELSE '' END
    || pgv.input('entry_date', 'date', pgv.t('ledger.field_date'), v_date, true)
    || pgv.input('reference', 'text', pgv.t('ledger.field_reference'), v_ref, true)
    || pgv.input('description', 'text', pgv.t('ledger.field_description'), v_desc, true),
    pgv.t('ledger.btn_save'));

  RETURN v_body;
END;
$function$;
