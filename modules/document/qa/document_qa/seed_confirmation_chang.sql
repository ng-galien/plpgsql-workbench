CREATE OR REPLACE FUNCTION document_qa.seed_confirmation_chang()
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_c uuid; v_g uuid;
  v_w constant real := 210;
  v_h constant real := 297;
  v_primary constant text := '#033345';
  v_red constant text := '#e53150';
  v_cream constant text := '#f9f2e8';
  v_grey constant text := '#636e72';
  v_so int := 0;
  v_logo uuid; v_automne uuid; v_machon uuid;
  v_icon_est uuid; v_icon_deg uuid; v_icon_piq uuid;
  v_bg_id uuid;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  SELECT id INTO v_logo FROM asset.asset WHERE filename = 'logo-mft.svg' LIMIT 1;
  SELECT id INTO v_automne FROM asset.asset WHERE filename = 'automne-bourgogne.jpg' LIMIT 1;
  SELECT id INTO v_machon FROM asset.asset WHERE filename = 'machon-bourguignon.jpg' LIMIT 1;
  SELECT id INTO v_icon_est FROM asset.asset WHERE filename = 'icon-estafette.svg' LIMIT 1;
  SELECT id INTO v_icon_deg FROM asset.asset WHERE filename = 'icon-degustation.svg' LIMIT 1;
  SELECT id INTO v_icon_piq FROM asset.asset WHERE filename = 'icon-piquenique.svg' LIMIT 1;
  SELECT id INTO v_bg_id FROM document.brand_guide WHERE name = 'My French Tour' AND tenant_id = 'dev';

  v_c := document.canvas_create('Confirmation — John & Mei Chang', 'A4', 'portrait', v_w, v_h, v_cream, 'confirmation');

  IF v_bg_id IS NOT NULL THEN
    UPDATE document.canvas SET brand_guide_id = v_bg_id WHERE id = v_c;
  END IF;

  -- ================================================================
  -- 1. HERO (0-85mm)
  -- ================================================================
  IF v_automne IS NOT NULL THEN
    PERFORM document.element_add(v_c, 'image', v_so, jsonb_build_object(
      'x',0,'y',0,'width',v_w,'height',85,'asset_id',v_automne,'objectFit','cover',
      'naturalWidth',1600,'naturalHeight',1067,'cropY',0.35,'name','hero'));
  ELSE
    PERFORM document.element_add(v_c, 'rect', v_so, jsonb_build_object('x',0,'y',0,'width',v_w,'height',85,'fill','#c5e3d7','name','hero-placeholder'));
  END IF;
  v_so := v_so + 1;

  IF v_logo IS NOT NULL THEN
    PERFORM document.element_add(v_c, 'image', v_so, jsonb_build_object('x',10,'y',8,'width',35,'height',12,'asset_id',v_logo,'opacity',0.9,'naturalWidth',200,'naturalHeight',60,'name','logo'));
  END IF;
  v_so := v_so + 1;

  PERFORM document.element_add(v_c, 'rect', v_so, jsonb_build_object('x',0,'y',55,'width',v_w,'height',30,'fill',v_primary,'opacity',0.75,'name','bandeau'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',72,'fill','#ffffff','name','titre','fontSize',11,'fontWeight','bold','textAnchor','middle','content','Your Exclusive Wine Journey'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',81,'fill','#ffffff','name','subtitle','fontSize',5,'fontStyle','italic','textAnchor','middle','content','Burgundy, France · 品味 Bourgogne'));
  v_so := v_so + 1;

  -- ================================================================
  -- 2. MESSAGE PERSONNEL (90-140mm)
  -- ================================================================
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',20,'y',98,'fill',v_primary,'name','salut','fontSize',7,'fontStyle','italic','content','Dear John & Mei,'));
  v_so := v_so + 1;

  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',20,'y',108,'fill',v_red,'name','welcome-cn','fontSize',5,'fontStyle','italic','content','欢迎 — Welcome to Burgundy.'));
  v_so := v_so + 1;

  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',20,'y',117,'fill',v_primary,'name','msg-1','fontSize',4.5,'content','We are honored to welcome you and your friends for an unforgettable'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',20,'y',123,'fill',v_primary,'name','msg-2','fontSize',4.5,'content','day exploring the legendary vineyards of Burgundy. This private'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',20,'y',129,'fill',v_primary,'name','msg-3','fontSize',4.5,'content','journey has been curated especially for your anniversary celebration'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',20,'y',135,'fill',v_primary,'name','msg-4','fontSize',4.5,'content','— ten beautiful years together.'));
  v_so := v_so + 1;

  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',20,'y',144,'fill',v_red,'name','msg-closing','fontSize',4.5,'fontStyle','italic','content','A journey of a lifetime — une expérience inoubliable.'));
  v_so := v_so + 1;

  -- Séparateur rouge (chance en Chine)
  PERFORM document.element_add(v_c, 'rect', v_so, jsonb_build_object('x',85,'y',150,'width',40,'height',1.5,'fill',v_red,'name','sep-msg'));
  v_so := v_so + 1;

  -- ================================================================
  -- 3. PROGRAMME (155-210mm)
  -- ================================================================
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',162,'fill',v_primary,'name','section-programme','fontSize',8,'fontWeight','bold','textAnchor','middle','content','Your Day · Votre Journée'));
  v_so := v_so + 1;

  -- Col 1: Departure (Estafette)
  v_g := document.element_add(v_c, 'group', v_so, '{"name":"col-departure"}'::jsonb);
  v_so := v_so + 1;
  IF v_icon_est IS NOT NULL THEN
    PERFORM document.element_add(v_c, 'image', v_so, jsonb_build_object('x',27,'y',168,'width',16,'height',12,'asset_id',v_icon_est,'name','icon-estafette','parent_id',v_g));
    v_so := v_so + 1;
  END IF;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',35,'y',188,'fill',v_primary,'name','col1-time','parent_id',v_g,'fontSize',4,'fontWeight','bold','textAnchor','middle','content','10:00 — Departure'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',35,'y',194,'fill',v_grey,'name','col1-desc1','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','Private Estafette from'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',35,'y',199,'fill',v_grey,'name','col1-desc2','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','your hotel'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',35,'y',206,'fill',v_primary,'name','col1-accent','parent_id',v_g,'fontSize',3.5,'fontStyle','italic','textAnchor','middle','content','La Route des Grands Crus'));
  v_so := v_so + 1;

  -- Col 2: Tastings
  v_g := document.element_add(v_c, 'group', v_so, '{"name":"col-tastings"}'::jsonb);
  v_so := v_so + 1;
  IF v_icon_deg IS NOT NULL THEN
    PERFORM document.element_add(v_c, 'image', v_so, jsonb_build_object('x',97,'y',168,'width',16,'height',12,'asset_id',v_icon_deg,'naturalWidth',113,'naturalHeight',113,'name','icon-tastings','parent_id',v_g));
    v_so := v_so + 1;
  END IF;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',105,'y',188,'fill',v_primary,'name','col2-time','parent_id',v_g,'fontSize',4,'fontWeight','bold','textAnchor','middle','content','12:00 — 干杯 Tastings'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',105,'y',194,'fill',v_grey,'name','col2-desc1','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','12 to 15 prestigious'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',105,'y',199,'fill',v_grey,'name','col2-desc2','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','wines'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',105,'y',206,'fill',v_primary,'name','col2-accent','parent_id',v_g,'fontSize',3.5,'fontStyle','italic','textAnchor','middle','content','Premiers & Grands Crus'));
  v_so := v_so + 1;

  -- Col 3: Lunch
  v_g := document.element_add(v_c, 'group', v_so, '{"name":"col-lunch"}'::jsonb);
  v_so := v_so + 1;
  IF v_icon_piq IS NOT NULL THEN
    PERFORM document.element_add(v_c, 'image', v_so, jsonb_build_object('x',167,'y',168,'width',16,'height',12,'asset_id',v_icon_piq,'naturalWidth',113,'naturalHeight',113,'name','icon-lunch','parent_id',v_g));
    v_so := v_so + 1;
  END IF;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',175,'y',188,'fill',v_primary,'name','col3-time','parent_id',v_g,'fontSize',4,'fontWeight','bold','textAnchor','middle','content','13:30 — Le Déjeuner'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',175,'y',194,'fill',v_grey,'name','col3-desc1','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','Exclusive lunch at a'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',175,'y',199,'fill',v_grey,'name','col3-desc2','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','private domaine'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',175,'y',206,'fill',v_primary,'name','col3-accent','parent_id',v_g,'fontSize',3.5,'fontStyle','italic','textAnchor','middle','content','Burgundian gastronomy'));
  v_so := v_so + 1;

  -- ================================================================
  -- 4. PHOTO AMBIANCE (215-250mm)
  -- ================================================================
  IF v_machon IS NOT NULL THEN
    PERFORM document.element_add(v_c, 'image', v_so, jsonb_build_object(
      'x',15,'y',215,'width',180,'height',35,'asset_id',v_machon,'objectFit','cover',
      'naturalWidth',1600,'naturalHeight',1312,'cropY',0.4,'borderRadius',4,'name','photo-ambiance'));
  END IF;
  v_so := v_so + 1;

  -- ================================================================
  -- 5. DÉTAILS (255-280mm)
  -- ================================================================
  PERFORM document.element_add(v_c, 'rect', v_so, jsonb_build_object('x',0,'y',255,'width',v_w,'height',24,'fill',v_primary,'name','details-bg'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',263,'fill','#ffffff','name','details-formule','fontSize',5,'fontWeight','bold','textAnchor','middle','content','Formule Immersion — La Journée des Épicuriens'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',269,'fill','#ffffff','name','details-info','fontSize',4,'textAnchor','middle','content','7 guests · Estafette Alouette 1974 · Saturday, October 18th 2026'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',274,'fill','#ffffff','name','details-pickup','fontSize',3.5,'textAnchor','middle','content','Pickup: 10:00 from Hôtel Le Cep, Beaune'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',279,'fill','#ffffff','name','details-price','fontSize',4,'fontStyle','italic','textAnchor','middle','content','190€ per person — 干杯 Cheers to ten years!'));
  v_so := v_so + 1;

  -- ================================================================
  -- 6. FOOTER (282-297mm)
  -- ================================================================
  PERFORM document.element_add(v_c, 'rect', v_so, jsonb_build_object('x',60,'y',283,'width',90,'height',1,'fill',v_red,'name','footer-sep'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',290,'fill',v_primary,'name','footer-contact','fontSize',3,'textAnchor','middle','content','Mélanie · +33 6 58 00 78 46 · hello@myfrenchtour.com'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',295,'fill',v_red,'name','footer-farewell','fontSize',3,'fontStyle','italic','textAnchor','middle','content','À bientôt en Bourgogne! · 期待与您相见!'));
  v_so := v_so + 1;

  RETURN v_c;
END;
$function$;
