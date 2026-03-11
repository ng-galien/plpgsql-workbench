CREATE OR REPLACE FUNCTION pgv_qa.get_atoms()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN
    '<section><h4>pgv.badge</h4>'
    || '<p>'
    || pgv.badge('default') || ' '
    || pgv.badge('success', 'success') || ' '
    || pgv.badge('danger', 'danger') || ' '
    || pgv.badge('warning', 'warning') || ' '
    || pgv.badge('info', 'info') || ' '
    || pgv.badge('primary', 'primary')
    || '</p></section>'
    || '<section><h4>pgv.stat + pgv.grid</h4>'
    || pgv.grid(
        pgv.stat('Utilisateurs', '1 234', '+12% ce mois'),
        pgv.stat('Revenu', pgv.money(42567.89), 'mensuel'),
        pgv.stat('Stockage', pgv.filesize(1073741824), 'utilise'))
    || '</section>'
    || '<section><h4>pgv.card</h4>'
    || pgv.grid(
        pgv.card('Titre simple', '<p>Contenu de la carte.</p>'),
        pgv.card('Avec footer', '<p>Carte avec action.</p>',
          pgv.action('toast_success', 'Action', NULL::jsonb, NULL, 'outline')))
    || '</section>'
    || '<section><h4>pgv.dl</h4>'
    || pgv.dl('Nom', 'Jean Dupont', 'Email', 'jean@example.com', 'Role', 'Admin', 'Statut', pgv.badge('actif', 'success'))
    || '</section>'
    || '<section><h4>pgv.money + pgv.filesize</h4>'
    || '<md>' || chr(10)
    || '| Montant | Taille |' || chr(10)
    || '|---------|--------|' || chr(10)
    || '| ' || pgv.money(0) || ' | ' || pgv.filesize(0) || ' |' || chr(10)
    || '| ' || pgv.money(1234.56) || ' | ' || pgv.filesize(1024) || ' |' || chr(10)
    || '| ' || pgv.money(99999.99) || ' | ' || pgv.filesize(5242880) || ' |' || chr(10)
    || '| ' || pgv.money(1000000) || ' | ' || pgv.filesize(1073741824) || ' |' || chr(10)
    || '</md></section>'
    || '<section><h4>pgv.error</h4>'
    || pgv.error('404', 'Page non trouvee', 'Le chemin /exemple n''existe pas.', 'Verifiez l''URL.')
    || '</section>';
END;
$function$;
