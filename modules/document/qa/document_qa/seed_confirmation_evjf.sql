CREATE OR REPLACE FUNCTION document_qa.seed_confirmation_evjf()
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_c uuid; v_g uuid;
  v_w constant real := 210;
  v_h constant real := 297;
  v_primary constant text := '#033345';
  v_red constant text := '#e53150';
  v_accent constant text := '#749fc3';
  v_cream constant text := '#f9f2e8';
  v_grey constant text := '#636e72';
  v_so int := 0;
  v_automne uuid; v_logo uuid; v_machon uuid;
  v_icon_deg uuid; v_icon_cave uuid; v_icon_piq uuid;
  v_bg_id uuid;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  SELECT id INTO v_automne FROM asset.asset WHERE filename = 'automne-bourgogne.jpg' LIMIT 1;
  SELECT id INTO v_logo FROM asset.asset WHERE filename = 'logo-mft.svg' LIMIT 1;
  SELECT id INTO v_machon FROM asset.asset WHERE filename = 'machon-bourguignon.jpg' LIMIT 1;
  SELECT id INTO v_icon_deg FROM asset.asset WHERE filename = 'icon-degustation.svg' LIMIT 1;
  SELECT id INTO v_icon_cave FROM asset.asset WHERE filename = 'icon-cave.svg' LIMIT 1;
  SELECT id INTO v_icon_piq FROM asset.asset WHERE filename = 'icon-piquenique.svg' LIMIT 1;
  SELECT id INTO v_bg_id FROM document.brand_guide WHERE name = 'My French Tour' AND tenant_id = 'dev';

  v_c := document.canvas_create('Confirmation EVJF — Caroline Dupuis', 'A4', 'portrait', v_w, v_h, v_cream, 'confirmation');
  IF v_bg_id IS NOT NULL THEN UPDATE document.canvas SET brand_guide_id = v_bg_id WHERE id = v_c; END IF;

  -- 1. HERO
  IF v_automne IS NOT NULL THEN
    PERFORM document.element_add(v_c, 'image', v_so, jsonb_build_object('x',0,'y',0,'width',v_w,'height',90,'asset_id',v_automne,'objectFit','cover','naturalWidth',1600,'naturalHeight',1067,'cropY',0.3,'name','hero'));
  ELSE
    PERFORM document.element_add(v_c, 'rect', v_so, jsonb_build_object('x',0,'y',0,'width',v_w,'height',90,'fill','#c5e3d7','name','hero-placeholder'));
  END IF;
  v_so := v_so + 1;

  IF v_logo IS NOT NULL THEN
    PERFORM document.element_add(v_c, 'image', v_so, jsonb_build_object('x',10,'y',8,'width',35,'height',12,'asset_id',v_logo,'opacity',0.9,'objectFit','contain','name','logo'));
  ELSE
    PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',28,'y',17,'fill','#ffffff','opacity',0.9,'name','logo-text','fontSize',8,'fontWeight','bold','content','MY FRENCH TOUR'));
  END IF;
  v_so := v_so + 1;

  PERFORM document.element_add(v_c, 'rect', v_so, jsonb_build_object('x',0,'y',60,'width',v_w,'height',30,'fill',v_primary,'opacity',0.7,'name','bandeau-titre'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',80,'fill','#ffffff','name','titre-hero','fontSize',12,'fontWeight','bold','textAnchor','middle','content','Votre EVJF en Bourgogne'));
  v_so := v_so + 1;

  -- 2. MESSAGE
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',20,'y',103,'fill',v_primary,'name','salut','fontSize',7,'fontStyle','italic','content','Chère Caroline,'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',20,'y',114,'fill',v_primary,'name','msg-1','fontSize',4.5,'content','Nous sommes ravis de vous accueillir, vous et vos 8 amies,'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',20,'y',120,'fill',v_primary,'name','msg-2','fontSize',4.5,'content','pour une journée d''exception dans les vignobles de Bourgogne.'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',20,'y',128,'fill',v_primary,'name','msg-3','fontSize',4.5,'content','Une escapade hors du temps vous attend à bord de notre'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',20,'y',134,'fill',v_primary,'name','msg-4','fontSize',4.5,'content','Estafette Alouette 1974, entre vignes, caves et saveurs.'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',20,'y',143,'fill',v_red,'name','msg-closing','fontSize',4.5,'fontStyle','italic','content','Préparez-vous à vivre des moments inoubliables.'));
  v_so := v_so + 1;

  -- 3. PROGRAMME
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',157,'fill',v_primary,'name','section-programme','fontSize',8,'fontWeight','bold','textAnchor','middle','content','Votre Journée'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'rect', v_so, jsonb_build_object('x',90,'y',161,'width',30,'height',1.5,'fill',v_red,'name','sep-programme'));
  v_so := v_so + 1;

  v_g := document.element_add(v_c, 'group', v_so, '{"name":"col-depart"}'::jsonb); v_so := v_so + 1;
  IF v_icon_deg IS NOT NULL THEN PERFORM document.element_add(v_c, 'image', v_so, jsonb_build_object('x',27,'y',167,'width',16,'height',12,'asset_id',v_icon_deg,'objectFit','contain','name','icon-depart','parent_id',v_g)); v_so := v_so + 1; END IF;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',35,'y',186,'fill',v_primary,'name','col1-time','parent_id',v_g,'fontSize',4,'fontWeight','bold','textAnchor','middle','content','10h — Départ')); v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',35,'y',193,'fill',v_grey,'name','col1-desc1','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','Balade dans les')); v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',35,'y',198,'fill',v_grey,'name','col1-desc2','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','vignobles de la')); v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',35,'y',203,'fill',v_grey,'name','col1-desc3','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','Côte de Beaune')); v_so := v_so + 1;

  v_g := document.element_add(v_c, 'group', v_so, '{"name":"col-caves"}'::jsonb); v_so := v_so + 1;
  IF v_icon_cave IS NOT NULL THEN PERFORM document.element_add(v_c, 'image', v_so, jsonb_build_object('x',97,'y',167,'width',16,'height',12,'asset_id',v_icon_cave,'objectFit','contain','name','icon-caves','parent_id',v_g)); v_so := v_so + 1; END IF;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',105,'y',186,'fill',v_primary,'name','col2-time','parent_id',v_g,'fontSize',4,'fontWeight','bold','textAnchor','middle','content','12h — Dégustations')); v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',105,'y',193,'fill',v_grey,'name','col2-desc1','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','5 à 6 vins d''exception')); v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',105,'y',198,'fill',v_grey,'name','col2-desc2','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','Premiers et')); v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',105,'y',203,'fill',v_grey,'name','col2-desc3','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','Grands Crus')); v_so := v_so + 1;

  v_g := document.element_add(v_c, 'group', v_so, '{"name":"col-dejeuner"}'::jsonb); v_so := v_so + 1;
  IF v_icon_piq IS NOT NULL THEN PERFORM document.element_add(v_c, 'image', v_so, jsonb_build_object('x',167,'y',167,'width',16,'height',12,'asset_id',v_icon_piq,'objectFit','contain','name','icon-dejeuner','parent_id',v_g)); v_so := v_so + 1; END IF;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',175,'y',186,'fill',v_primary,'name','col3-time','parent_id',v_g,'fontSize',4,'fontWeight','bold','textAnchor','middle','content','13h — Déjeuner')); v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',175,'y',193,'fill',v_grey,'name','col3-desc1','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','Machon bourguignon')); v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',175,'y',198,'fill',v_grey,'name','col3-desc2','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','dans les vignes')); v_so := v_so + 1;

  -- 4. PHOTO
  IF v_machon IS NOT NULL THEN
    PERFORM document.element_add(v_c, 'image', v_so, jsonb_build_object('x',15,'y',215,'width',180,'height',35,'asset_id',v_machon,'objectFit','cover','naturalWidth',1600,'naturalHeight',1312,'cropY',0.4,'borderRadius',4,'name','photo-ambiance'));
  END IF;
  v_so := v_so + 1;

  -- 5. DÉTAILS
  PERFORM document.element_add(v_c, 'rect', v_so, jsonb_build_object('x',0,'y',255,'width',v_w,'height',22,'fill',v_primary,'name','details-bg')); v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',264,'fill','#ffffff','name','details-formule','fontSize',5,'fontWeight','bold','textAnchor','middle','content','Formule Immersion — Journée des Épicuriens')); v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',271,'fill','#ffffff','name','details-info','fontSize',4,'textAnchor','middle','content','9 personnes · 190€/pers · Samedi 14 juin 2026')); v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',275,'fill',v_accent,'name','details-depart','fontSize',3.5,'textAnchor','middle','content','Départ : 10h depuis votre hôtel à Beaune')); v_so := v_so + 1;

  -- 6. FOOTER
  PERFORM document.element_add(v_c, 'rect', v_so, jsonb_build_object('x',60,'y',281,'width',90,'height',1,'fill',v_red,'name','footer-sep')); v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',289,'fill',v_primary,'name','footer-contact','fontSize',3,'textAnchor','middle','content','Mélanie · +33 6 58 00 78 46 · contact@myfrenchtour.com')); v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',294,'fill',v_red,'name','footer-web','fontSize',3,'textAnchor','middle','content','myfrenchtour.com')); v_so := v_so + 1;

  RETURN v_c;
END;
$function$;
