CREATE OR REPLACE FUNCTION project.get_chantiers(p_statut text DEFAULT NULL::text, p_q text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_body  text;
  v_rows  text[];
  r       record;
BEGIN
  -- Formulaire de filtre
  v_body := format(
    '<form method="get" action="%s" class="grid" style="grid-template-columns:auto auto 1fr auto;align-items:end;gap:.5rem">'
    || '<label>Statut<select name="p_statut">'
    || '<option value="">Tous</option>'
    || '<option value="preparation"%s>Préparation</option>'
    || '<option value="execution"%s>En cours</option>'
    || '<option value="reception"%s>Réception</option>'
    || '<option value="clos"%s>Clos</option>'
    || '</select></label>'
    || '<label>Recherche<input type="search" name="p_q" value="%s" placeholder="Numéro, client, objet…"></label>'
    || '<div></div>'
    || '<button type="submit">Filtrer</button>'
    || '</form>',
    pgv.call_ref('get_chantiers'),
    CASE WHEN p_statut = 'preparation' THEN ' selected' ELSE '' END,
    CASE WHEN p_statut = 'execution'   THEN ' selected' ELSE '' END,
    CASE WHEN p_statut = 'reception'   THEN ' selected' ELSE '' END,
    CASE WHEN p_statut = 'clos'        THEN ' selected' ELSE '' END,
    pgv.esc(COALESCE(p_q, ''))
  );

  -- Requête filtrée
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT c.id, c.client_id, c.devis_id, c.numero, cl.name AS client, c.objet, c.statut,
           project._avancement_global(c.id) AS pct,
           c.date_debut, d.numero AS devis_numero
      FROM project.chantier c
      JOIN crm.client cl ON cl.id = c.client_id
      LEFT JOIN quote.devis d ON d.id = c.devis_id
     WHERE (p_statut IS NULL OR p_statut = '' OR c.statut = p_statut)
       AND (p_q IS NULL OR p_q = ''
            OR c.numero ILIKE '%' || p_q || '%'
            OR cl.name  ILIKE '%' || p_q || '%'
            OR c.objet  ILIKE '%' || p_q || '%')
     ORDER BY c.updated_at DESC
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_chantier', jsonb_build_object('p_id', r.id)), pgv.esc(r.numero)),
      format('<a href="/crm/client?p_id=%s">%s</a>', r.client_id, pgv.esc(r.client)),
      pgv.esc(r.objet),
      project._statut_badge(r.statut),
      pgv.badge(r.pct::text || ' %'),
      CASE WHEN r.devis_numero IS NOT NULL
        THEN format('<a href="/quote/devis?p_id=%s">%s</a>', r.devis_id, pgv.esc(r.devis_numero))
        ELSE '—' END,
      COALESCE(to_char(r.date_debut, 'DD/MM/YYYY'), '—')
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty('Aucun chantier trouvé', 'Essayez de modifier vos filtres.');
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY['Numéro', 'Client', 'Objet', 'Statut', 'Avancement', 'Devis', 'Début'],
      v_rows, 15
    );
  END IF;

  v_body := v_body || '<p>'
    || format('<a href="%s" role="button">Nouveau chantier</a>', pgv.call_ref('get_chantier_form'))
    || '</p>';

  RETURN v_body;
END;
$function$;
