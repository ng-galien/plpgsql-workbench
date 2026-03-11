CREATE OR REPLACE FUNCTION ledger.get_entry_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_entry record;
  v_body text;
  v_title text;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO v_entry FROM ledger.journal_entry WHERE id = p_id;
    IF NOT FOUND THEN RETURN pgv.empty('Écriture introuvable'); END IF;
    IF v_entry.posted THEN RETURN pgv.alert('Écriture validée : modification impossible.', 'danger'); END IF;
    v_title := 'Modifier ' || v_entry.reference;
  ELSE
    v_title := 'Nouvelle écriture';
  END IF;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[
    'Écritures', pgv.call_ref('get_entries'),
    v_title
  ]);

  v_body := v_body || '<form data-rpc="post_entry_save">';

  IF p_id IS NOT NULL THEN
    v_body := v_body || '<input type="hidden" name="id" value="' || p_id || '">';
  END IF;

  v_body := v_body
    || '<label>Date <input type="date" name="entry_date" value="'
      || CASE WHEN p_id IS NOT NULL THEN to_char(v_entry.entry_date, 'YYYY-MM-DD') ELSE to_char(CURRENT_DATE, 'YYYY-MM-DD') END
      || '" required></label>'
    || '<label>Référence <input type="text" name="reference" value="'
      || CASE WHEN p_id IS NOT NULL THEN pgv.esc(v_entry.reference) ELSE '' END
      || '" required placeholder="EX: ACH-001"></label>'
    || '<label>Description <input type="text" name="description" value="'
      || CASE WHEN p_id IS NOT NULL THEN pgv.esc(v_entry.description) ELSE '' END
      || '" required placeholder="Achat matériaux chantier X"></label>'
    || '<button type="submit">Enregistrer</button>'
    || '</form>';

  RETURN v_body;
END;
$function$;
