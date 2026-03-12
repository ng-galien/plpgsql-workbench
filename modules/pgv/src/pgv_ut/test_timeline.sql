CREATE OR REPLACE FUNCTION pgv_ut.test_timeline()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
  v_items jsonb := '[
    {"date":"2026-03-10","label":"Devis créé","detail":"Montant: 1500€ HT","badge":"info"},
    {"date":"2026-03-11","label":"Devis envoyé","badge":"success"},
    {"date":"2026-03-12","label":"Paiement reçu","detail":"Virement bancaire","badge":"primary"}
  ]';
BEGIN
  v_html := pgv.timeline(v_items);

  -- Container
  RETURN NEXT ok(v_html LIKE '%class="pgv-tl"%', 'container class pgv-tl');

  -- Items rendered
  RETURN NEXT ok(v_html LIKE '%pgv-tl-item%', 'timeline items present');
  RETURN NEXT ok(v_html LIKE '%pgv-tl-dot%', 'dot elements present');

  -- Dates
  RETURN NEXT ok(v_html LIKE '%pgv-tl-date%', 'date rendered');
  RETURN NEXT ok(v_html LIKE '%2026-03-10%', 'first date value');

  -- Labels
  RETURN NEXT ok(v_html LIKE '%pgv-tl-label%', 'label rendered');
  RETURN NEXT ok(v_html LIKE '%Devis créé%', 'first label value');

  -- Detail
  RETURN NEXT ok(v_html LIKE '%pgv-tl-detail%', 'detail rendered');
  RETURN NEXT ok(v_html LIKE '%1500%', 'detail content');

  -- Badge colors on dots
  RETURN NEXT ok(v_html LIKE '%pgv-tl-dot-info%', 'info dot color');
  RETURN NEXT ok(v_html LIKE '%pgv-tl-dot-success%', 'success dot color');
  RETURN NEXT ok(v_html LIKE '%pgv-tl-dot-primary%', 'primary dot color');

  -- No badge → plain dot
  v_html := pgv.timeline('[{"label":"Simple event"}]');
  RETURN NEXT ok(v_html LIKE '%class="pgv-tl-dot"%', 'plain dot without badge');
  RETURN NEXT ok(v_html NOT LIKE '%pgv-tl-date%', 'no date when omitted');
  RETURN NEXT ok(v_html NOT LIKE '%pgv-tl-detail%', 'no detail when omitted');

  -- XSS
  v_html := pgv.timeline('[{"label":"<script>alert(1)</script>"}]');
  RETURN NEXT ok(v_html NOT LIKE '%<script>%', 'labels escaped');
END;
$function$;
