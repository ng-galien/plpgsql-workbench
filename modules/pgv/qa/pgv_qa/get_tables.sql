CREATE OR REPLACE FUNCTION pgv_qa.get_tables()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN
    '<section><h4>Table simple (tri automatique)</h4>'
    || '<md>' || chr(10)
    || '| Nom | Role | Statut |' || chr(10)
    || '|-----|------|--------|' || chr(10)
    || '| Alice Martin | Developpeur | ' || pgv.badge('actif', 'success') || ' |' || chr(10)
    || '| Bob Durand | Designer | ' || pgv.badge('actif', 'success') || ' |' || chr(10)
    || '| Claire Petit | Chef de projet | ' || pgv.badge('conge', 'warning') || ' |' || chr(10)
    || '| David Moreau | Developpeur | ' || pgv.badge('actif', 'success') || ' |' || chr(10)
    || '| Eva Bernard | QA | ' || pgv.badge('inactif', 'danger') || ' |' || chr(10)
    || '</md></section>'
    || '<section><h4>Table paginee (3 lignes/page)</h4>'
    || '<md data-page="3">' || chr(10)
    || '| # | Commande | Montant | Date | Etat |' || chr(10)
    || '|---|----------|---------|------|------|' || chr(10)
    || '| 1 | CMD-001 | ' || pgv.money(245.00) || ' | 15/01/2026 | ' || pgv.badge('payee', 'success') || ' |' || chr(10)
    || '| 2 | CMD-002 | ' || pgv.money(89.50) || ' | 18/01/2026 | ' || pgv.badge('payee', 'success') || ' |' || chr(10)
    || '| 3 | CMD-003 | ' || pgv.money(1250.00) || ' | 22/01/2026 | ' || pgv.badge('en cours', 'warning') || ' |' || chr(10)
    || '| 4 | CMD-004 | ' || pgv.money(45.99) || ' | 25/01/2026 | ' || pgv.badge('payee', 'success') || ' |' || chr(10)
    || '| 5 | CMD-005 | ' || pgv.money(670.00) || ' | 02/02/2026 | ' || pgv.badge('annulee', 'danger') || ' |' || chr(10)
    || '| 6 | CMD-006 | ' || pgv.money(320.75) || ' | 08/02/2026 | ' || pgv.badge('en cours', 'warning') || ' |' || chr(10)
    || '| 7 | CMD-007 | ' || pgv.money(158.00) || ' | 14/02/2026 | ' || pgv.badge('payee', 'success') || ' |' || chr(10)
    || '| 8 | CMD-008 | ' || pgv.money(2100.00) || ' | 20/02/2026 | ' || pgv.badge('brouillon', 'default') || ' |' || chr(10)
    || '| 9 | CMD-009 | ' || pgv.money(430.25) || ' | 01/03/2026 | ' || pgv.badge('payee', 'success') || ' |' || chr(10)
    || '| 10 | CMD-010 | ' || pgv.money(75.00) || ' | 05/03/2026 | ' || pgv.badge('en cours', 'info') || ' |' || chr(10)
    || '</md></section>'
    || '<section><h4>pgv.md_table (helper PL/pgSQL)</h4>'
    || '<p>Genere le markdown depuis des tableaux PL/pgSQL :</p>'
    || pgv.md_table(
        ARRAY['Metrique', 'Valeur', 'Tendance'],
        ARRAY['Pages vues', '12 480', pgv.badge('+18%', 'success'),
              'Visiteurs', '3 241', pgv.badge('+5%', 'info'),
              'Rebond', '42%', pgv.badge('-3%', 'success'),
              'Conversion', '2.8%', pgv.badge('stable', 'default')])
    || '</section>'
    || '<section><h4>pgv.table() — declaratif avec filtres + pagination server-side</h4>'
    || pgv.table(jsonb_build_object(
         'rpc', 'data_demo',
         'schema', 'pgv_qa',
         'page_size', 10,
         'filters', jsonb_build_array(
           jsonb_build_object('name', 'p_status', 'type', 'select', 'label', 'Statut',
             'options', jsonb_build_array(
               jsonb_build_array('', 'Tous'),
               jsonb_build_array('active', 'Actif'),
               jsonb_build_array('draft', 'Brouillon'),
               jsonb_build_array('archived', 'Archive'))),
           jsonb_build_object('name', 'q', 'type', 'search', 'label', 'Recherche')),
         'cols', jsonb_build_array(
           jsonb_build_object('key', 'id', 'label', '#'),
           jsonb_build_object('key', 'author', 'label', 'Auteur'),
           jsonb_build_object('key', 'title', 'label', 'Titre'),
           jsonb_build_object('key', 'status', 'label', 'Statut', 'class', 'pgv-col-badge'),
           jsonb_build_object('key', 'date', 'label', 'Date', 'class', 'pgv-col-date'))))
    || '</section>';
END;
$function$;
