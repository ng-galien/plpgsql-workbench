-- Asset seed data for dev tenant — My French Tour photo library
DO $$
BEGIN
  INSERT INTO asset.asset (path, filename, mime_type, status, title, description, tags, width, height, orientation, season, credit, usage_hint, colors, thumb_path, classified_at)
  VALUES
    ('/images/automne-bourgogne.jpg', 'automne-bourgogne.jpg', 'image/jpeg', 'classified',
     '2CV et Estafette dans les vignes d''automne',
     'Citroën 2CV bordeaux et Renault Estafette vert d''eau garées sur un chemin herbeux entre les vignes.',
     ARRAY['2cv','estafette','vignoble','automne','bourgogne','vintage','paysage','village'],
     1200, 800, 'landscape', 'autumn', 'My French Tour', 'web banner',
     ARRAY['#6B8E23','#8B6914','#800020','#87CEEB'], '/images/thumbs/automne-bourgogne.jpg', now()),

    ('/images/oenotourisme.jpg', 'oenotourisme.jpg', 'image/jpeg', 'classified',
     'Dégustation de crémant en plein air',
     'Femme souriante verse du crémant de Bourgogne dans un verre en plein air.',
     ARRAY['oenotourisme','crémant','dégustation','plein air','bourgogne','vin','été','convivialité'],
     800, 1200, 'portrait', 'summer', 'My French Tour', 'brochure',
     ARRAY['#2E5A1E','#F5DEB3','#1A1A1A','#87CEEB'], '/images/thumbs/oenotourisme.jpg', now()),

    ('/images/machon-bourguignon.jpg', 'machon-bourguignon.jpg', 'image/jpeg', 'classified',
     'Pique-nique gourmet bourguignon',
     'Panier en osier avec nappe vichy, bouteille de Bourgogne, gougères et fromages.',
     ARRAY['gastronomie','pique-nique','bourgogne','vin blanc','gougères','fromage','terroir','panier'],
     1000, 800, 'landscape', 'summer', 'Etienne Ramousse', 'card',
     ARRAY['#8B5E3C','#F5DEB3','#556B2F','#DAA520'], '/images/thumbs/machon-bourguignon.jpg', now()),

    ('/images/tour-2cv.png', 'tour-2cv.png', 'image/png', 'classified',
     'Illustration Citroën 2CV bleu ciel',
     'Illustration vectorielle d''une Citroën 2CV bleu ciel vue de profil.',
     ARRAY['2cv','illustration','vintage','flat design','véhicule','bleu','citroën'],
     700, 250, 'landscape', NULL, 'My French Tour', 'poster',
     ARRAY['#6FA8DC','#1A1A1A','#FFFFFF','#C0C0C0'], '/images/thumbs/tour-2cv.png', now()),

    ('/images/sur-mesure.jpg', 'sur-mesure.jpg', 'image/jpeg', 'to_classify',
     NULL, NULL, '{}', NULL, NULL, NULL, NULL, NULL, NULL, ARRAY[]::text[], '/images/thumbs/sur-mesure.jpg', NULL),

    ('/images/estafette.png', 'estafette.png', 'image/png', 'to_classify',
     NULL, NULL, '{}', NULL, NULL, NULL, NULL, NULL, NULL, ARRAY[]::text[], '/images/thumbs/estafette.png', NULL),

    ('/images/automne-bourgogne-2.jpg', 'automne-bourgogne-2.jpg', 'image/jpeg', 'classified',
     'Pique-nique à l''Estafette dans les vignes d''automne',
     'Vue arrière de l''Estafette garée au bord des vignes automnales.',
     ARRAY['estafette','pique-nique','vignoble','automne','bourgogne','gastronomie','vintage'],
     1200, 800, 'landscape', 'autumn', 'My French Tour', 'web banner',
     ARRAY['#8B6914','#6B8E23','#87CEEB','#F5DEB3'], '/images/thumbs/automne-bourgogne-2.jpg', now()),

    ('/images/oenotourisme-2.jpg', 'oenotourisme-2.jpg', 'image/jpeg', 'classified',
     'Couple dégustant du vin sur un muret dans les vignes',
     'Couple assis de dos sur un muret en pierre sèche au milieu des vignobles.',
     ARRAY['couple','oenotourisme','vignoble','2cv','bourgogne','été','muret','romantique'],
     1200, 800, 'landscape', 'summer', 'Etienne Ramousse', 'web banner',
     ARRAY['#2E5A1E','#87CEEB','#6FA8DC','#C0C0A0'], '/images/thumbs/oenotourisme-2.jpg', now()),

    ('/images/oenotourisme-3.jpg', 'oenotourisme-3.jpg', 'image/jpeg', 'classified',
     'Vue aérienne de l''Estafette entre les vignobles',
     'Vue drone sur l''Estafette circulant entre des rangées de vignes.',
     ARRAY['drone','aérien','estafette','vignoble','bourgogne','été','paysage','nature'],
     1200, 800, 'landscape', 'summer', 'Etienne Ramousse', 'web banner',
     ARRAY['#2E5A1E','#3B7A2C','#87CEEB','#F0E68C'], '/images/thumbs/oenotourisme-3.jpg', now()),

    ('/images/oenotourisme-4.jpg', 'oenotourisme-4.jpg', 'image/jpeg', 'classified',
     'Tour en 2CV décapotée dans les vignobles',
     'Citroën 2CV bleue décapotée avec logo My French Tour, roulant entre les vignes.',
     ARRAY['2cv','tour','vignoble','couple','bourgogne','été','décapotée','aventure'],
     1200, 800, 'landscape', 'summer', 'Etienne Ramousse', 'poster',
     ARRAY['#6FA8DC','#2E5A1E','#F0E68C','#87CEEB'], '/images/thumbs/oenotourisme-4.jpg', now()),

    ('/images/vignoble-aerien.jpg', 'vignoble-aerien.jpg', 'image/jpeg', 'classified',
     'Cave voûtée aux tonneaux de Meursault',
     'Cave voûtée en briques avec deux rangées de tonneaux de chêne.',
     ARRAY['cave','tonneaux','meursault','vin','bourgogne','oenotourisme','patrimoine','chêne'],
     1200, 800, 'landscape', NULL, 'Etienne Ramousse', 'brochure',
     ARRAY['#DAA520','#8B5E3C','#4A1A2E','#D2B48C'], '/images/thumbs/vignoble-aerien.jpg', now()),

    ('/images/mickael-portrait.jpg', 'mickael-portrait.jpg', 'image/jpeg', 'classified',
     'Portrait de Mickaël — fondateur My French Tour',
     'Portrait souriant d''un homme barbu aux yeux bleus.',
     ARRAY['portrait','fondateur','équipe','mickael','sourire','élégant'],
     800, 800, 'square', NULL, 'Etienne Ramousse', 'card',
     ARRAY['#B87333','#FFFFFF','#1A1A3E','#D2B48C'], '/images/thumbs/mickael-portrait.jpg', now()),

    ('/images/bon-cadeau.png', 'bon-cadeau.png', 'image/png', 'classified',
     'Bon cadeau My French Tour',
     'Illustration vintage d''un bon cadeau en forme de billet.',
     ARRAY['bon cadeau','illustration','vintage','logo','bourgogne','2cv','estafette','marketing'],
     1200, 500, 'landscape', NULL, 'My French Tour', 'card',
     ARRAY['#BDD1A0','#1A1A3E','#E63030','#F5DEB3'], '/images/thumbs/bon-cadeau.png', now()),

    ('/images/balade-vignoble.jpg', 'balade-vignoble.jpg', 'image/jpeg', 'classified',
     'Guide au volant — balade dans les vignobles',
     'Femme souriante au volant d''un véhicule vintage.',
     ARRAY['guide','balade','vignoble','portrait','vintage','chapeau','convivialité'],
     800, 800, 'square', 'summer', 'Etienne Ramousse', 'brochure',
     ARRAY['#D2691E','#2E5A1E','#F5DEB3','#87CEEB'], '/images/thumbs/balade-vignoble.jpg', now()),

    ('/images/tour-2cv-couleur.png', 'tour-2cv-couleur.png', 'image/png', 'classified',
     'Illustration Citroën 2CV bleue — vue détaillée',
     'Illustration vectorielle détaillée d''une Citroën 2CV bleu ciel.',
     ARRAY['2cv','illustration','vintage','flat design','véhicule','bleu','citroën','détaillé'],
     500, 500, 'square', NULL, 'My French Tour', 'poster',
     ARRAY['#6FA8DC','#1A1A1A','#FFFFFF','#808080'], '/images/thumbs/tour-2cv-couleur.png', now()),

    ('/images/logo-mft.svg', 'logo-mft.svg', 'image/svg+xml', 'classified',
     'Logo My French Tour', 'Logo principal de My French Tour.',
     ARRAY['logo','marque','identité visuelle','my french tour','svg'],
     400, 400, 'square', NULL, 'My French Tour', 'logo',
     ARRAY['#1A1A3E','#E63030','#FFFFFF','#F5DEB3'], '/images/logo-mft.svg', now()),

    ('/images/icon-estafette.svg', 'icon-estafette.svg', 'image/svg+xml', 'classified',
     'Icône Renault Estafette', 'Icône carrée Estafette de profil.',
     ARRAY['icône','estafette','véhicule','vintage','svg','navigation'],
     65, 65, 'square', NULL, 'My French Tour', 'icon',
     ARRAY['#87CEEB','#FFFFFF'], '/images/icon-estafette.svg', now()),

    ('/images/icon-2cv.svg', 'icon-2cv.svg', 'image/svg+xml', 'classified',
     'Icône Citroën 2CV', 'Icône carrée 2CV de profil.',
     ARRAY['icône','2cv','véhicule','vintage','svg','navigation','citroën'],
     113, 113, 'square', NULL, 'My French Tour', 'icon',
     ARRAY['#6FA8DC','#FFFFFF'], '/images/icon-2cv.svg', now()),

    ('/images/icon-degustation.svg', 'icon-degustation.svg', 'image/svg+xml', 'classified',
     'Icône dégustation de vin', 'Icône SVG verre de vin.',
     ARRAY['icône','dégustation','vin','verre','svg','navigation'],
     113, 113, 'square', NULL, 'My French Tour', 'icon',
     ARRAY['#BDD1E8','#E63030'], '/images/icon-degustation.svg', now()),

    ('/images/icon-cave.svg', 'icon-cave.svg', 'image/svg+xml', 'classified',
     'Icône visite de cave', 'Icône SVG tonneau de vin.',
     ARRAY['icône','cave','tonneau','vin','svg','navigation'],
     113, 113, 'square', NULL, 'My French Tour', 'icon',
     ARRAY['#E63030','#AA2725','#8F4F43'], '/images/icon-cave.svg', now()),

    ('/images/icon-piquenique.svg', 'icon-piquenique.svg', 'image/svg+xml', 'classified',
     'Icône pique-nique gourmet', 'Icône SVG panier pique-nique.',
     ARRAY['icône','pique-nique','panier','vin','svg','navigation','gastronomie'],
     113, 113, 'square', NULL, 'My French Tour', 'icon',
     ARRAY['#E63030','#F6A017','#073320','#FCC563'], '/images/icon-piquenique.svg', now()),

    ('/images/estafette-vector.svg', 'estafette-vector.svg', 'image/svg+xml', 'classified',
     'Illustration vectorielle Estafette détaillée', 'Illustration SVG Estafette.',
     ARRAY['estafette','illustration','véhicule','vintage','svg','vecteur'],
     400, 250, 'landscape', NULL, 'My French Tour', 'poster',
     ARRAY['#87CEEB','#FFFFFF','#1A1A1A'], '/images/estafette-vector.svg', now())

  ON CONFLICT DO NOTHING;
END $$;
