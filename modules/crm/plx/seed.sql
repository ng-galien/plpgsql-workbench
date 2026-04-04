-- CRM seed data for dev tenant
DO $$
DECLARE
  v_c1 int; v_c2 int; v_c3 int; v_c4 int; v_c5 int;
BEGIN
  -- Companies
  INSERT INTO crm.client (tenant_id, type, name, email, phone, address, city, postal_code, tier, notes)
  VALUES ('dev', 'company', 'Menuiserie Dupont', 'contact@dupont-menuiserie.fr', '01 42 36 78 90', '12 rue des Ateliers', 'Lyon', '69003', 'premium', 'Client historique, gros volumes bois massif')
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_c1;

  INSERT INTO crm.client (tenant_id, type, name, email, phone, address, city, postal_code, tier)
  VALUES ('dev', 'company', 'BTP Renov Sud', 'info@btprenovsud.fr', '04 91 55 12 34', '45 avenue du Prado', 'Marseille', '13008', 'standard')
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_c2;

  INSERT INTO crm.client (tenant_id, type, name, email, phone, address, city, postal_code, tier, notes)
  VALUES ('dev', 'company', 'Atelier Bois & Co', 'hello@boisandco.fr', '05 56 44 33 22', '8 quai des Chartrons', 'Bordeaux', '33000', 'premium', 'Partenaire salon Batimat')
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_c3;

  -- Individuals
  INSERT INTO crm.client (tenant_id, type, name, email, phone, address, city, postal_code, tier)
  VALUES ('dev', 'individual', 'Marie Lefebvre', 'marie.lefebvre@gmail.com', '06 12 34 56 78', '3 impasse des Lilas', 'Nantes', '44000', 'standard')
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_c4;

  INSERT INTO crm.client (tenant_id, type, name, email, phone, city, postal_code, tier, active)
  VALUES ('dev', 'individual', 'Jean-Pierre Martin', 'jp.martin@free.fr', '06 98 76 54 32', 'Toulouse', '31000', 'standard', false)
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_c5;

  -- Skip contacts/interactions if clients already existed (idempotent)
  IF v_c1 IS NULL THEN RETURN; END IF;

  -- Contacts
  INSERT INTO crm.contact (tenant_id, client_id, is_primary, payload) VALUES
  ('dev', v_c1, true,  '{"name":"Pierre Dupont","role":"Gérant","email":"pierre@dupont-menuiserie.fr","phone":"06 11 22 33 44"}'::jsonb),
  ('dev', v_c1, false, '{"name":"Sophie Dupont","role":"Comptabilité","email":"compta@dupont-menuiserie.fr"}'::jsonb),
  ('dev', v_c2, true,  '{"name":"Karim Benali","role":"Chef de chantier","phone":"06 55 44 33 22"}'::jsonb),
  ('dev', v_c3, true,  '{"name":"Isabelle Moreau","role":"Directrice","email":"isabelle@boisandco.fr","phone":"06 77 88 99 00"}'::jsonb),
  ('dev', v_c3, false, '{"name":"Lucas Petit","role":"Commercial","email":"lucas@boisandco.fr"}'::jsonb);

  -- Interactions
  INSERT INTO crm.interaction (tenant_id, client_id, type, payload, created_at) VALUES
  ('dev', v_c1, 'call',  '{"subject":"Commande charpente","details":"Demande devis 40m² charpente traditionnelle"}'::jsonb, now() - interval '15 days'),
  ('dev', v_c1, 'visit', '{"subject":"Visite atelier","details":"Visite technique pour mesures sur site"}'::jsonb, now() - interval '8 days'),
  ('dev', v_c1, 'email', '{"subject":"Envoi devis","details":"Devis DV-2024-042 envoyé par mail"}'::jsonb, now() - interval '5 days'),
  ('dev', v_c2, 'call',  '{"subject":"Premier contact","details":"Prospect via recommandation, intéressé par nos services"}'::jsonb, now() - interval '3 days'),
  ('dev', v_c3, 'visit', '{"subject":"Salon Batimat","details":"Rencontré sur le salon, échange cartes"}'::jsonb, now() - interval '30 days'),
  ('dev', v_c3, 'email', '{"subject":"Suivi salon","details":"Envoi catalogue et tarifs"}'::jsonb, now() - interval '25 days'),
  ('dev', v_c4, 'call',  '{"subject":"Demande terrasse","details":"Terrasse bois composite 25m², rdv planifié"}'::jsonb, now() - interval '2 days');
END $$;
