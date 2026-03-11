CREATE OR REPLACE FUNCTION crm.get_index()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_total int;
  v_active int;
  v_companies int;
  v_interactions_month int;
  v_rows text[];
  v_body text;
  r record;
BEGIN
  SELECT count(*)::int, count(*) FILTER (WHERE active)::int, count(*) FILTER (WHERE type = 'company')::int
    INTO v_total, v_active, v_companies
    FROM crm.client;

  SELECT count(*)::int INTO v_interactions_month
    FROM crm.interaction
   WHERE created_at >= date_trunc('month', now());

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat('Total clients', v_total::text),
    pgv.stat('Actifs', v_active::text),
    pgv.stat('Entreprises', v_companies::text),
    pgv.stat('Interactions ce mois', v_interactions_month::text)
  ]);

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT c.id, c.name, crm.type_label(c.type) AS type_label,
           c.city, c.tier, c.active,
           (SELECT count(*) FROM crm.interaction i WHERE i.client_id = c.id) AS nb_interactions
      FROM crm.client c
     ORDER BY c.updated_at DESC
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_client', jsonb_build_object('p_id', r.id)), pgv.esc(r.name)),
      r.type_label,
      COALESCE(r.city, '—'),
      pgv.badge(upper(r.tier), crm.tier_variant(r.tier)),
      r.nb_interactions::text,
      CASE WHEN r.active THEN 'Oui' ELSE 'Non' END
    ];
  END LOOP;

  IF v_total = 0 THEN
    v_body := v_body || pgv.empty('Aucun client', 'Créez votre premier client pour commencer.');
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY['Client', 'Type', 'Ville', 'Tier', 'Interactions', 'Actif'],
      v_rows,
      20
    );
  END IF;

  v_body := v_body || format('<p><a href="%s" role="button">Nouveau client</a></p>', pgv.call_ref('get_client_form'));

  RETURN v_body;
END;
$function$;
