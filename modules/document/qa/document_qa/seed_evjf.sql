CREATE OR REPLACE FUNCTION document_qa.seed_evjf()
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
  v_dark constant text := '#222222';
  v_grey constant text := '#636e72';
  v_so int := 0;
  v_vignoble uuid; v_estafette uuid; v_oenotourisme uuid; v_machon uuid;
  v_icon_deg uuid; v_icon_cave uuid; v_icon_piq uuid;
  v_bg_id uuid;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  -- Lookup assets
  SELECT id INTO v_vignoble FROM asset.asset WHERE filename = 'automne-bourgogne.jpg' LIMIT 1;
  SELECT id INTO v_estafette FROM asset.asset WHERE filename = 'estafette.png' LIMIT 1;
  SELECT id INTO v_oenotourisme FROM asset.asset WHERE filename = 'oenotourisme.jpg' LIMIT 1;
  SELECT id INTO v_machon FROM asset.asset WHERE filename = 'machon-bourguignon.jpg' LIMIT 1;
  SELECT id INTO v_icon_deg FROM asset.asset WHERE filename = 'icon-degustation.svg' LIMIT 1;
  SELECT id INTO v_icon_cave FROM asset.asset WHERE filename = 'icon-cave.svg' LIMIT 1;
  SELECT id INTO v_icon_piq FROM asset.asset WHERE filename = 'icon-piquenique.svg' LIMIT 1;
  SELECT id INTO v_bg_id FROM document.brand_guide WHERE name = 'My French Tour' AND tenant_id = 'dev';

  v_c := document.canvas_create('Plaquette EVJF — My French Tour', 'A4', 'portrait', v_w, v_h, v_cream, 'plaquette');

  IF v_bg_id IS NOT NULL THEN
    UPDATE document.canvas SET brand_guide_id = v_bg_id WHERE id = v_c;
  END IF;

  -- ================================================================
  -- 1. PHOTO HERO (0-80mm)
  -- ================================================================
  IF v_vignoble IS NOT NULL THEN
    PERFORM document.element_add(v_c, 'image', v_so, jsonb_build_object(
      'x',0,'y',0,'width',v_w,'height',80,'asset_id',v_vignoble,'objectFit','cover','name','hero-photo'));
  ELSE
    PERFORM document.element_add(v_c, 'rect', v_so, jsonb_build_object(
      'x',0,'y',0,'width',v_w,'height',80,'fill','#c5e3d7','name','hero-placeholder'));
  END IF;
  v_so := v_so + 1;

  -- 2. LOGO overlay (sur la photo)
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object(
    'x',v_w/2,'y',45,'fill','#ffffff','name','logo','fontSize',14,'fontWeight','bold','textAnchor','middle',
    'content','MY FRENCH TOUR','opacity',0.9));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object(
    'x',v_w/2,'y',58,'fill','#ffffff','name','tagline','fontSize',5,'fontStyle','italic','textAnchor','middle',
    'content','Oenotourisme d''exception en Bourgogne','opacity',0.85));
  v_so := v_so + 1;

  -- ================================================================
  -- 3. TITRE (85mm)
  -- ================================================================
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object(
    'x',v_w/2,'y',93,'fill',v_primary,'name','titre','fontSize',16,'fontWeight','bold','textAnchor','middle',
    'content','EVJF Insolite en Bourgogne'));
  v_so := v_so + 1;

  -- 4. ACCROCHE (100mm)
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object(
    'x',v_w/2,'y',103,'fill',v_primary,'name','accroche','fontSize',4.5,'fontStyle','italic','textAnchor','middle',
    'content','Offrez à la future mariée une aventure inoubliable'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object(
    'x',v_w/2,'y',109,'fill',v_primary,'name','accroche-2','fontSize',4.5,'fontStyle','italic','textAnchor','middle',
    'content','dans les vignobles de Bourgogne, à bord de nos véhicules vintage'));
  v_so := v_so + 1;

  -- 5. SÉPARATEUR rouge
  PERFORM document.element_add(v_c, 'rect', v_so, jsonb_build_object(
    'x',85,'y',115,'width',40,'height',1.5,'fill',v_red,'name','sep-red'));
  v_so := v_so + 1;

  -- ================================================================
  -- 6. PHOTO ESTAFETTE (120-155mm)
  -- ================================================================
  IF v_estafette IS NOT NULL THEN
    PERFORM document.element_add(v_c, 'image', v_so, jsonb_build_object(
      'x',45,'y',120,'width',120,'height',35,'asset_id',v_estafette,'objectFit','cover','name','img-estafette'));
  END IF;
  v_so := v_so + 1;

  -- ================================================================
  -- 7. SECTION FORMULES (160mm)
  -- ================================================================
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object(
    'x',v_w/2,'y',165,'fill',v_primary,'name','section-formules','fontSize',8,'fontWeight','bold','textAnchor','middle',
    'content','Nos Formules'));
  v_so := v_so + 1;

  -- Card 1: La Petite Virée
  v_g := document.element_add(v_c, 'group', v_so, '{"name":"card-petite-viree"}'::jsonb);
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'rect', v_so, jsonb_build_object('x',12,'y',170,'width',58,'height',55,'fill','#ffffff','borderRadius',3,'name','card1-bg','parent_id',v_g));
  v_so := v_so + 1;
  IF v_icon_deg IS NOT NULL THEN
    PERFORM document.element_add(v_c, 'image', v_so, jsonb_build_object('x',33,'y',173,'width',16,'height',12,'asset_id',v_icon_deg,'name','card1-icon','parent_id',v_g));
    v_so := v_so + 1;
  END IF;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',41,'y',192,'fill',v_primary,'name','card1-title','parent_id',v_g,'fontSize',5,'fontWeight','bold','textAnchor','middle','content','La Petite Virée'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',41,'y',199,'fill',v_grey,'name','card1-dur','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','2h — Apéro + Gougères'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',41,'y',205,'fill',v_grey,'name','card1-det','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','Balade vignobles'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'line', v_so, jsonb_build_object('x1',22,'y1',210,'x2',60,'y2',210,'stroke',v_accent,'stroke_width',0.3,'parent_id',v_g,'name','card1-sep'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',41,'y',219,'fill',v_red,'name','card1-price','parent_id',v_g,'fontSize',7,'fontWeight','bold','textAnchor','middle','content','70€/pers'));
  v_so := v_so + 1;

  -- Card 2: Découverte
  v_g := document.element_add(v_c, 'group', v_so, '{"name":"card-decouverte"}'::jsonb);
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'rect', v_so, jsonb_build_object('x',76,'y',170,'width',58,'height',55,'fill','#ffffff','borderRadius',3,'name','card2-bg','parent_id',v_g));
  v_so := v_so + 1;
  IF v_icon_cave IS NOT NULL THEN
    PERFORM document.element_add(v_c, 'image', v_so, jsonb_build_object('x',97,'y',173,'width',16,'height',12,'asset_id',v_icon_cave,'name','card2-icon','parent_id',v_g));
    v_so := v_so + 1;
  END IF;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',105,'y',192,'fill',v_primary,'name','card2-title','parent_id',v_g,'fontSize',5,'fontWeight','bold','textAnchor','middle','content','Découverte'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',105,'y',199,'fill',v_grey,'name','card2-dur','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','3-4h — 5 à 6 vins'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',105,'y',205,'fill',v_grey,'name','card2-det','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','Visites de caves'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'line', v_so, jsonb_build_object('x1',86,'y1',210,'x2',124,'y2',210,'stroke',v_accent,'stroke_width',0.3,'parent_id',v_g,'name','card2-sep'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',105,'y',219,'fill',v_red,'name','card2-price','parent_id',v_g,'fontSize',7,'fontWeight','bold','textAnchor','middle','content','90€/pers'));
  v_so := v_so + 1;

  -- Card 3: Immersion (highlighted)
  v_g := document.element_add(v_c, 'group', v_so, '{"name":"card-immersion"}'::jsonb);
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'rect', v_so, jsonb_build_object('x',140,'y',170,'width',58,'height',55,'fill',v_primary,'opacity',0.06,'borderRadius',3,'name','card3-bg','parent_id',v_g));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'rect', v_so, jsonb_build_object('x',140,'y',170,'width',58,'height',55,'fill','none','stroke',v_primary,'stroke_width',0.5,'borderRadius',3,'name','card3-border','parent_id',v_g));
  v_so := v_so + 1;
  IF v_icon_piq IS NOT NULL THEN
    PERFORM document.element_add(v_c, 'image', v_so, jsonb_build_object('x',161,'y',173,'width',16,'height',12,'asset_id',v_icon_piq,'name','card3-icon','parent_id',v_g));
    v_so := v_so + 1;
  END IF;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',169,'y',192,'fill',v_primary,'name','card3-title','parent_id',v_g,'fontSize',5,'fontWeight','bold','textAnchor','middle','content','Immersion'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',169,'y',199,'fill',v_grey,'name','card3-dur','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','Journée — 10 à 19 vins'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',169,'y',205,'fill',v_grey,'name','card3-det','parent_id',v_g,'fontSize',3,'textAnchor','middle','content','Déjeuner gastronomique'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'line', v_so, jsonb_build_object('x1',150,'y1',210,'x2',188,'y2',210,'stroke',v_accent,'stroke_width',0.3,'parent_id',v_g,'name','card3-sep'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',169,'y',219,'fill',v_red,'name','card3-price','parent_id',v_g,'fontSize',7,'fontWeight','bold','textAnchor','middle','content','190€/pers'));
  v_so := v_so + 1;

  -- ================================================================
  -- 8. PHOTO DÉGUSTATION (230-260mm)
  -- ================================================================
  IF v_machon IS NOT NULL THEN
    PERFORM document.element_add(v_c, 'image', v_so, jsonb_build_object(
      'x',0,'y',230,'width',v_w,'height',30,'asset_id',v_machon,'objectFit','cover','name','img-machon'));
  END IF;
  v_so := v_so + 1;

  -- ================================================================
  -- 9. FOOTER (263-297mm)
  -- ================================================================
  PERFORM document.element_add(v_c, 'rect', v_so, jsonb_build_object('x',0,'y',263,'width',v_w,'height',34,'fill',v_primary,'name','footer-bg'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',274,'fill',v_red,'name','footer-cta','fontSize',6,'fontWeight','bold','textAnchor','middle','content','Réservez votre EVJF'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',282,'fill','#ffffff','name','footer-contact','fontSize',4,'textAnchor','middle','content','contact@myfrenchtour.com — +33 (0)6 58 00 78 46'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',289,'fill',v_accent,'name','footer-web','fontSize',3.5,'textAnchor','middle','content','myfrenchtour.com'));
  v_so := v_so + 1;
  PERFORM document.element_add(v_c, 'text', v_so, jsonb_build_object('x',v_w/2,'y',295,'fill',v_grey,'name','footer-mentions','fontSize',2.5,'textAnchor','middle','content','17 rue Goujon, 71150 Rully — SIRET 82882453200026 — IM021230001'));
  v_so := v_so + 1;

  RETURN v_c;
END;
$function$;
