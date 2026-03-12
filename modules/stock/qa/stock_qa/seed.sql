CREATE OR REPLACE FUNCTION stock_qa.seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_dep_atelier int;
  v_dep_vehicule int;
  v_chene int;
  v_douglas int;
  v_vis int;
  v_tirefond int;
  v_osb int;
  v_laine int;
  v_huile int;
  v_colle int;
  v_equerre int;
  v_pointe int;
  v_fournisseur_bois int;
  v_fournisseur_quincaillerie int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  -- Fournisseurs CRM (réutilise ou crée)
  SELECT id INTO v_fournisseur_bois FROM crm.client WHERE name = 'Scierie du Jura' AND tenant_id = 'dev';
  IF NOT FOUND THEN
    INSERT INTO crm.client (name, type, city, tenant_id)
    VALUES ('Scierie du Jura', 'company', 'Arbois', 'dev')
    RETURNING id INTO v_fournisseur_bois;
  END IF;

  SELECT id INTO v_fournisseur_quincaillerie FROM crm.client WHERE name = 'Quincaillerie Pro' AND tenant_id = 'dev';
  IF NOT FOUND THEN
    INSERT INTO crm.client (name, type, city, tenant_id)
    VALUES ('Quincaillerie Pro', 'company', 'Besançon', 'dev')
    RETURNING id INTO v_fournisseur_quincaillerie;
  END IF;

  -- Dépôts
  INSERT INTO stock.depot (nom, type, adresse, tenant_id) VALUES
    ('Atelier principal', 'atelier', '12 rue des Chênes, Lons-le-Saunier', 'dev') RETURNING id INTO v_dep_atelier;
  INSERT INTO stock.depot (nom, type, tenant_id) VALUES
    ('Véhicule utilitaire', 'vehicule', 'dev') RETURNING id INTO v_dep_vehicule;
  INSERT INTO stock.depot (nom, type, adresse, tenant_id) VALUES
    ('Chantier Martin', 'chantier', '8 impasse des Tilleuls, Poligny', 'dev');

  -- Articles
  INSERT INTO stock.article (reference, designation, categorie, unite, prix_achat, pmp, seuil_mini, fournisseur_id, tenant_id) VALUES
    ('BOIS-CHENE-27', 'Chêne massif 27mm', 'bois', 'm3', 850.00, 850.0000, 2, v_fournisseur_bois, 'dev') RETURNING id INTO v_chene;
  INSERT INTO stock.article (reference, designation, categorie, unite, prix_achat, pmp, seuil_mini, fournisseur_id, tenant_id) VALUES
    ('BOIS-DOUG-45', 'Douglas 45mm', 'bois', 'm3', 420.00, 420.0000, 3, v_fournisseur_bois, 'dev') RETURNING id INTO v_douglas;
  INSERT INTO stock.article (reference, designation, categorie, unite, prix_achat, pmp, seuil_mini, fournisseur_id, tenant_id) VALUES
    ('QUINC-VIS-5x50', 'Vis inox 5x50 (boîte 200)', 'quincaillerie', 'u', 18.50, 18.5000, 5, v_fournisseur_quincaillerie, 'dev') RETURNING id INTO v_vis;
  INSERT INTO stock.article (reference, designation, categorie, unite, prix_achat, pmp, seuil_mini, fournisseur_id, tenant_id) VALUES
    ('QUINC-TIRE-8x80', 'Tirefond 8x80 (boîte 50)', 'quincaillerie', 'u', 24.00, 24.0000, 3, v_fournisseur_quincaillerie, 'dev') RETURNING id INTO v_tirefond;
  INSERT INTO stock.article (reference, designation, categorie, unite, prix_achat, pmp, seuil_mini, fournisseur_id, tenant_id) VALUES
    ('PAN-OSB-18', 'OSB 18mm 2500x1250', 'panneau', 'u', 32.00, 32.0000, 10, v_fournisseur_bois, 'dev') RETURNING id INTO v_osb;
  INSERT INTO stock.article (reference, designation, categorie, unite, prix_achat, pmp, seuil_mini, fournisseur_id, tenant_id) VALUES
    ('ISOL-LAINE-60', 'Laine de bois 60mm', 'isolant', 'm2', 8.50, 8.5000, 20, v_fournisseur_bois, 'dev') RETURNING id INTO v_laine;
  INSERT INTO stock.article (reference, designation, categorie, unite, prix_achat, pmp, fournisseur_id, tenant_id) VALUES
    ('FIN-HUILE-LIN', 'Huile de lin 5L', 'finition', 'u', 35.00, 35.0000, v_fournisseur_quincaillerie, 'dev') RETURNING id INTO v_huile;
  INSERT INTO stock.article (reference, designation, categorie, unite, prix_achat, pmp, fournisseur_id, tenant_id) VALUES
    ('FIN-COLLE-PU', 'Colle PU D4 750g', 'finition', 'u', 22.00, 22.0000, v_fournisseur_quincaillerie, 'dev') RETURNING id INTO v_colle;
  INSERT INTO stock.article (reference, designation, categorie, unite, prix_achat, pmp, seuil_mini, fournisseur_id, tenant_id) VALUES
    ('QUINC-EQUER-90', 'Équerre 90° renforcée', 'quincaillerie', 'u', 3.50, 3.5000, 20, v_fournisseur_quincaillerie, 'dev') RETURNING id INTO v_equerre;
  INSERT INTO stock.article (reference, designation, categorie, unite, prix_achat, pmp, fournisseur_id, tenant_id) VALUES
    ('QUINC-POINT-70', 'Pointe tête plate 70mm (kg)', 'quincaillerie', 'kg', 8.00, 8.0000, v_fournisseur_quincaillerie, 'dev') RETURNING id INTO v_pointe;

  -- Mouvements: entrées fournisseur
  INSERT INTO stock.mouvement (article_id, depot_id, type, quantite, prix_unitaire, reference, tenant_id) VALUES
    (v_chene, v_dep_atelier, 'entree', 5, 850.00, 'BL-2026-001', 'dev'),
    (v_douglas, v_dep_atelier, 'entree', 8, 420.00, 'BL-2026-001', 'dev'),
    (v_vis, v_dep_atelier, 'entree', 20, 18.50, 'BL-2026-002', 'dev'),
    (v_tirefond, v_dep_atelier, 'entree', 10, 24.00, 'BL-2026-002', 'dev'),
    (v_osb, v_dep_atelier, 'entree', 30, 32.00, 'BL-2026-003', 'dev'),
    (v_laine, v_dep_atelier, 'entree', 50, 8.50, 'BL-2026-003', 'dev'),
    (v_huile, v_dep_atelier, 'entree', 6, 35.00, 'BL-2026-004', 'dev'),
    (v_colle, v_dep_atelier, 'entree', 8, 22.00, 'BL-2026-004', 'dev'),
    (v_equerre, v_dep_atelier, 'entree', 50, 3.50, 'BL-2026-005', 'dev'),
    (v_pointe, v_dep_atelier, 'entree', 10, 8.00, 'BL-2026-005', 'dev');

  -- Sorties chantier
  INSERT INTO stock.mouvement (article_id, depot_id, type, quantite, prix_unitaire, reference, tenant_id) VALUES
    (v_chene, v_dep_atelier, 'sortie', -2, 850.00, 'CHANTIER-MARTIN', 'dev'),
    (v_osb, v_dep_atelier, 'sortie', -8, 32.00, 'CHANTIER-MARTIN', 'dev'),
    (v_vis, v_dep_atelier, 'sortie', -5, 18.50, 'CHANTIER-MARTIN', 'dev');

  -- Transfert atelier -> véhicule
  INSERT INTO stock.mouvement (article_id, depot_id, type, quantite, prix_unitaire, depot_destination_id, reference, tenant_id) VALUES
    (v_equerre, v_dep_atelier, 'transfert', -15, 3.50, v_dep_vehicule, 'TRANSFERT-001', 'dev'),
    (v_equerre, v_dep_vehicule, 'transfert', 15, 3.50, v_dep_atelier, 'TRANSFERT-001', 'dev');

  -- Laine de bois: sortie pour mettre sous seuil (alerte)
  INSERT INTO stock.mouvement (article_id, depot_id, type, quantite, prix_unitaire, reference, tenant_id) VALUES
    (v_laine, v_dep_atelier, 'sortie', -35, 8.50, 'CHANTIER-DUPONT', 'dev');
END;
$function$;
