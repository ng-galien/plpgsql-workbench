CREATE OR REPLACE FUNCTION crm.get_index(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_q text;
  v_type text;
  v_tier text;
  v_active text;
  v_total int;
  v_new_month int;
  v_interactions_week int;
  v_rows text[];
  v_body text;
  v_city text;
  r record;
BEGIN
  -- Extract filters
  v_q := NULLIF(trim(COALESCE(p_params->>'q', '')), '');
  v_type := NULLIF(trim(COALESCE(p_params->>'type', '')), '');
  v_tier := NULLIF(trim(COALESCE(p_params->>'tier', '')), '');
  v_active := NULLIF(trim(COALESCE(p_params->>'active', '')), '');
  v_city := NULLIF(trim(COALESCE(p_params->>'city', '')), '');

  -- Stats (unfiltered)
  SELECT count(*)::int INTO v_total FROM crm.client;
  SELECT count(*)::int INTO v_new_month FROM crm.client WHERE created_at >= date_trunc('month', now());
  SELECT count(*)::int INTO v_interactions_week FROM crm.interaction WHERE created_at >= date_trunc('week', now());

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat('Total clients', v_total::text),
    pgv.stat('Nouveaux ce mois', v_new_month::text),
    pgv.stat('Interactions cette semaine', v_interactions_week::text)
  ]);

  -- Search/filter form
  v_body := v_body
    || '<form>'
    || '<div class="grid">'
    || pgv.input('q', 'search', 'Recherche nom/email', v_q)
    || pgv.sel('type', 'Type', '[{"label":"Tous","value":""},{"label":"Particulier","value":"individual"},{"label":"Entreprise","value":"company"}]'::jsonb, COALESCE(v_type, ''))
    || pgv.sel('tier', 'Tier', '[{"label":"Tous","value":""},{"label":"Standard","value":"standard"},{"label":"Premium","value":"premium"},{"label":"VIP","value":"vip"}]'::jsonb, COALESCE(v_tier, ''))
    || pgv.sel('active', 'Actif', '[{"label":"Tous","value":""},{"label":"Oui","value":"true"},{"label":"Non","value":"false"}]'::jsonb, COALESCE(v_active, ''))
    || pgv.input('city', 'text', 'Ville', v_city)
    || '</div>'
    || '<button type="submit" class="secondary">Filtrer</button>'
    || '</form>';

  -- Client list with filters
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT c.id, c.name, crm.type_label(c.type) AS type_label,
           c.city, c.tier, c.active,
           (SELECT count(*) FROM crm.interaction i WHERE i.client_id = c.id) AS nb_interactions
      FROM crm.client c
     WHERE (v_q IS NULL OR c.name ILIKE '%' || v_q || '%' OR c.email ILIKE '%' || v_q || '%')
       AND (v_type IS NULL OR c.type = v_type)
       AND (v_tier IS NULL OR c.tier = v_tier)
       AND (v_active IS NULL OR c.active = (v_active = 'true'))
       AND (v_city IS NULL OR c.city ILIKE '%' || v_city || '%')
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
  ELSIF cardinality(v_rows) = 0 THEN
    v_body := v_body || pgv.empty('Aucun résultat pour ces filtres.');
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY['Client', 'Type', 'Ville', 'Tier', 'Interactions', 'Actif'],
      v_rows,
      20
    );
  END IF;

  v_body := v_body || format('<p><a href="%s" role="button">Nouveau client</a> <a href="%s" role="button" class="secondary">Import CSV</a></p>', pgv.call_ref('get_client_form'), pgv.call_ref('get_import'));

  RETURN v_body;
END;
$function$;
