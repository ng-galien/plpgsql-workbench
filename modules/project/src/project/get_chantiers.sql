CREATE OR REPLACE FUNCTION project.get_chantiers()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_rows text[];
  r record;
BEGIN
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT c.id, c.client_id, c.devis_id, c.numero, cl.name AS client, c.objet, c.statut,
           project._avancement_global(c.id) AS pct,
           c.date_debut, c.date_fin_prevue, d.numero AS devis_numero
      FROM project.chantier c
      JOIN crm.client cl ON cl.id = c.client_id
      LEFT JOIN quote.devis d ON d.id = c.devis_id
     ORDER BY CASE c.statut
       WHEN 'execution' THEN 1
       WHEN 'preparation' THEN 2
       WHEN 'reception' THEN 3
       WHEN 'clos' THEN 4
     END, c.updated_at DESC
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
      COALESCE(to_char(r.date_debut, 'DD/MM/YYYY'), '—'),
      COALESCE(to_char(r.date_fin_prevue, 'DD/MM/YYYY'), '—')
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    RETURN pgv.empty('Aucun chantier', 'Créez votre premier chantier pour commencer.')
      || '<p>' || format('<a href="%s" role="button">Nouveau chantier</a>', pgv.call_ref('get_chantier_form')) || '</p>';
  END IF;

  RETURN pgv.md_table(
    ARRAY['Numéro', 'Client', 'Objet', 'Statut', 'Avancement', 'Devis', 'Début', 'Fin prévue'],
    v_rows, 20
  )
  || '<p>' || format('<a href="%s" role="button">Nouveau chantier</a>', pgv.call_ref('get_chantier_form')) || '</p>';
END;
$function$;
