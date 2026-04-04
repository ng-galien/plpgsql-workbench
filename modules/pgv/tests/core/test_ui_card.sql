CREATE OR REPLACE FUNCTION pgv_ut.test_ui_card()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v jsonb;
  h jsonb;
BEGIN
  -- ui_card_header
  h := pgv.ui_card_header('◎', 'Test', pgv.ui_badge('VIP', 'success'));
  RETURN NEXT is(h->>'icon', '◎', 'header: icon');
  RETURN NEXT is(h->>'title', 'Test', 'header: title');
  RETURN NEXT ok(jsonb_array_length(h->'badges') = 1, 'header: 1 badge');

  -- header without badges
  h := pgv.ui_card_header('✉', 'No badges');
  RETURN NEXT ok(h->'badges' IS NULL, 'header: no badges key when empty');

  -- ui_stat
  v := pgv.ui_stat('42', 'Count');
  RETURN NEXT is(v->>'type', 'stat', 'stat: type');
  RETURN NEXT is(v->>'value', '42', 'stat: value');
  RETURN NEXT is(v->>'label', 'Count', 'stat: label');
  RETURN NEXT ok(v->'variant' IS NULL, 'stat: no variant by default');

  v := pgv.ui_stat('3', 'Pending', 'warn');
  RETURN NEXT is(v->>'variant', 'warn', 'stat: variant set');

  -- ui_card compact
  v := pgv.ui_card('crm://client/1', 'compact', pgv.ui_card_header('◎', 'Dupont'));
  RETURN NEXT is(v->>'type', 'card', 'compact: type');
  RETURN NEXT is(v->>'level', 'compact', 'compact: level');
  RETURN NEXT is(v->>'entity_uri', 'crm://client/1', 'compact: entity_uri');
  RETURN NEXT ok(v->'body' IS NULL, 'compact: no body');
  RETURN NEXT ok(v->'actions' IS NULL, 'compact: no actions');

  -- ui_card standard
  v := pgv.ui_card(
    'docs://charte/ocean', 'standard',
    pgv.ui_card_header('🎨', 'Ocean'),
    jsonb_build_array(pgv.ui_stat('6', 'Couleurs')),
    jsonb_build_array(pgv.ui_card('docs://document/1', 'compact', pgv.ui_card_header('📄', 'Facture')))
  );
  RETURN NEXT is(v->>'level', 'standard', 'standard: level');
  RETURN NEXT ok(jsonb_array_length(v->'body') = 1, 'standard: has body');
  RETURN NEXT ok(jsonb_array_length(v->'related') = 1, 'standard: has related');
  RETURN NEXT is(v->'related'->0->>'level', 'compact', 'standard: related is compact card');
  RETURN NEXT ok(v->'actions' IS NULL, 'standard: no actions');

  -- ui_card expanded
  v := pgv.ui_card(
    'docs://charte/ocean', 'expanded',
    pgv.ui_card_header('🎨', 'Ocean'),
    jsonb_build_array(pgv.ui_stat('6', 'Couleurs')),
    NULL,
    jsonb_build_array(pgv.ui_action('Supprimer', 'delete', 'docs://charte/ocean', 'danger', 'Confirmer ?'))
  );
  RETURN NEXT is(v->>'level', 'expanded', 'expanded: level');
  RETURN NEXT ok(jsonb_array_length(v->'actions') = 1, 'expanded: has actions');
  RETURN NEXT is(v->'actions'->0->>'verb', 'delete', 'expanded: action verb');
END;
$function$;
