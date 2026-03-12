CREATE OR REPLACE FUNCTION purchase_qa.seed()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_fournisseur1_id int;
  v_fournisseur2_id int;
  v_cmd1_id int;
  v_cmd2_id int;
  v_cmd3_id int;
  v_cmd4_id int;
  v_l1 int; v_l2 int; v_l3 int; v_l4 int; v_l5 int; v_l6 int; v_l7 int; v_l8 int;
  v_rec_id int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  -- Fournisseurs (via CRM)
  INSERT INTO crm.client (type, name, email, phone, city, tags)
  VALUES ('company', 'Bois & Matériaux SARL', 'contact@boismat.fr', '01 23 45 67 89', 'Lyon', ARRAY['fournisseur'])
  RETURNING id INTO v_fournisseur1_id;

  INSERT INTO crm.client (type, name, email, phone, city, tags)
  VALUES ('company', 'Quincaillerie Martin', 'info@martinquinc.fr', '04 56 78 90 12', 'Grenoble', ARRAY['fournisseur'])
  RETURNING id INTO v_fournisseur2_id;

  -- CMD1: brouillon
  INSERT INTO purchase.commande (numero, fournisseur_id, objet, notes)
  VALUES ('CMD-2026-001', v_fournisseur1_id, 'Bois charpente atelier', 'Livraison matin svp')
  RETURNING id INTO v_cmd1_id;

  INSERT INTO purchase.ligne (commande_id, sort_order, description, quantite, unite, prix_unitaire)
  VALUES (v_cmd1_id, 1, 'Poutre chêne 200x20x10cm', 4, 'u', 85.00)
  RETURNING id INTO v_l1;
  INSERT INTO purchase.ligne (commande_id, sort_order, description, quantite, unite, prix_unitaire, tva_rate)
  VALUES (v_cmd1_id, 2, 'Tasseaux sapin 40x40mm 2m', 20, 'u', 3.50, 20.00)
  RETURNING id INTO v_l2;

  -- CMD2: envoyée (en attente réception)
  INSERT INTO purchase.commande (numero, fournisseur_id, objet, statut, date_livraison)
  VALUES ('CMD-2026-002', v_fournisseur2_id, 'Visserie projet cuisine', 'envoyee', now()::date + 7)
  RETURNING id INTO v_cmd2_id;

  INSERT INTO purchase.ligne (commande_id, sort_order, description, quantite, unite, prix_unitaire)
  VALUES (v_cmd2_id, 1, 'Vis inox 5x50 (boîte 200)', 3, 'u', 12.90)
  RETURNING id INTO v_l3;
  INSERT INTO purchase.ligne (commande_id, sort_order, description, quantite, unite, prix_unitaire)
  VALUES (v_cmd2_id, 2, 'Charnières laiton 50mm', 12, 'u', 4.50)
  RETURNING id INTO v_l4;
  INSERT INTO purchase.ligne (commande_id, sort_order, description, quantite, unite, prix_unitaire)
  VALUES (v_cmd2_id, 3, 'Colle PU D4 750ml', 2, 'u', 18.00)
  RETURNING id INTO v_l5;

  -- CMD3: partiellement reçue
  INSERT INTO purchase.commande (numero, fournisseur_id, objet, statut)
  VALUES ('CMD-2026-003', v_fournisseur1_id, 'Panneaux MDF + contreplaqué', 'partiellement_recue')
  RETURNING id INTO v_cmd3_id;

  INSERT INTO purchase.ligne (commande_id, sort_order, description, quantite, unite, prix_unitaire)
  VALUES (v_cmd3_id, 1, 'Panneau MDF 19mm 250x122cm', 5, 'u', 42.00)
  RETURNING id INTO v_l6;
  INSERT INTO purchase.ligne (commande_id, sort_order, description, quantite, unite, prix_unitaire)
  VALUES (v_cmd3_id, 2, 'Contreplaqué bouleau 15mm 250x122cm', 3, 'u', 65.00)
  RETURNING id INTO v_l7;

  -- Réception partielle CMD3 (3 MDF sur 5, 0 contreplaqué)
  INSERT INTO purchase.reception (commande_id, numero, notes)
  VALUES (v_cmd3_id, 'REC-2026-001', 'Livraison partielle — contreplaqué en rupture')
  RETURNING id INTO v_rec_id;

  INSERT INTO purchase.reception_ligne (reception_id, ligne_id, quantite_recue)
  VALUES (v_rec_id, v_l6, 3);

  -- CMD4: reçue + facturée
  INSERT INTO purchase.commande (numero, fournisseur_id, objet, statut)
  VALUES ('CMD-2026-004', v_fournisseur2_id, 'Outillage portatif', 'recue')
  RETURNING id INTO v_cmd4_id;

  INSERT INTO purchase.ligne (commande_id, sort_order, description, quantite, unite, prix_unitaire)
  VALUES (v_cmd4_id, 1, 'Disques abrasifs grain 120 (lot 50)', 2, 'u', 15.90)
  RETURNING id INTO v_l8;

  -- Réception complète CMD4
  INSERT INTO purchase.reception (commande_id, numero)
  VALUES (v_cmd4_id, 'REC-2026-002')
  RETURNING id INTO v_rec_id;

  INSERT INTO purchase.reception_ligne (reception_id, ligne_id, quantite_recue)
  VALUES (v_rec_id, v_l8, 2);

  -- Factures fournisseur
  INSERT INTO purchase.facture_fournisseur (commande_id, numero_fournisseur, montant_ht, montant_ttc, date_facture, date_echeance, statut)
  VALUES (v_cmd4_id, 'FM-8842', 31.80, 38.16, now()::date - 10, now()::date + 20, 'validee');

  INSERT INTO purchase.facture_fournisseur (commande_id, numero_fournisseur, montant_ht, montant_ttc, date_facture, statut)
  VALUES (v_cmd3_id, 'BM-2026-0412', 126.00, 151.20, now()::date - 3, 'recue');

  RETURN 'purchase_qa.seed() OK — 4 commandes, 2 réceptions, 2 factures, 2 fournisseurs CRM';
END;
$function$;
