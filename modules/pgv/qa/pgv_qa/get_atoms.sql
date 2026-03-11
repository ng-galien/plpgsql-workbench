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
    || '<section><h4>pgv.md_table</h4>'
    || pgv.md_table(
        ARRAY['Produit', 'Prix', 'Stock'],
        ARRAY['Widget A', pgv.money(29.99), '142',
              'Widget B', pgv.money(59.50), '38',
              'Widget C', pgv.money(149.00), '7'])
    || '</section>'
    || '<section><h4>pgv.href (liens externes)</h4>'
    || '<p>'
    || '<a href="' || pgv.href('https://picocss.com') || '">PicoCSS</a> | '
    || '<a href="' || pgv.href('https://alpinejs.dev') || '">Alpine.js</a> | '
    || '<a href="' || pgv.href('mailto:contact@example.com') || '">Email</a> | '
    || '<a href="' || pgv.href('tel:+33123456789') || '">Telephone</a>'
    || '</p></section>'
    || '<section><h4>pgv.error</h4>'
    || pgv.error('404', 'Page non trouvee', 'Le chemin /exemple n''existe pas.', 'Verifiez l''URL.')
    || '</section>'
    || '<section><h4>pgv.script (Alpine.js inline)</h4>'
    || '<div x-data="{count: 0}">'
    || '<p>Compteur: <strong x-text="count">0</strong></p>'
    || '<div class="grid">'
    || '<button @click="count++">+1</button>'
    || '<button @click="count--" class="secondary">-1</button>'
    || '<button @click="count=0" class="outline">Reset</button>'
    || '</div></div>'
    || pgv.script('console.log(''pgv.script demo loaded'')') 
    || '</section>'
    || '<section><h4>pgv.card (imbrication)</h4>'
    || pgv.card('Utilisateur', pgv.dl('Nom', 'Marie Durand', 'Role', pgv.badge('admin', 'primary'), 'Email', 'marie@example.com'),
        pgv.action('toast_success', 'Contacter', NULL::jsonb, NULL, 'outline'))
    || '</section>';
END;
$function$;
