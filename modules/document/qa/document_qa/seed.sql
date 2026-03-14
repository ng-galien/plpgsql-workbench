CREATE OR REPLACE FUNCTION document_qa.seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_estafette_id uuid;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);
  PERFORM document.i18n_seed();

  PERFORM document.set_company(
    'Atelier Bois & Fils', '44512345600012', 'FR44512345600',
    '12 rue des Artisans', 'Lyon', '69003',
    '04 72 00 00 00', 'contact@bois-fils.fr', 'https://bois-fils.fr',
    'SARL au capital de 50 000€ — RCS Lyon 445 123 456');

  SELECT id INTO v_estafette_id FROM asset.asset WHERE filename = 'estafette.png' LIMIT 1;

  INSERT INTO document.brand_guide (name, primary_color, secondary_color, accent_color, background_color, text_color,
    font_title, font_title_weight, font_title_size, font_body, font_body_weight, font_body_size, logo_asset_id, props)
  VALUES ('My French Tour', '#033345', '#e53150', '#749fc3', '#f9f2e8', '#033345',
    'Libre Baskerville', 'bold', 14, 'Source Sans 3', 'normal', 5, v_estafette_id,
    '{"vert_eau":"#c5e3d7","footer":"#222222","blanc":"#ffffff"}'::jsonb);

  PERFORM document_qa.seed_showcase();
  PERFORM document_qa.seed_affiche();
  PERFORM document_qa.seed_carte_visite();
  PERFORM document_qa.seed_evjf();
  PERFORM document_qa.seed_confirmation_evjf();
  PERFORM document_qa.seed_confirmation_doe();
END;
$function$;
