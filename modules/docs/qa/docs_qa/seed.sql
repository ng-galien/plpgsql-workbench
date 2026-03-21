CREATE OR REPLACE FUNCTION docs_qa.seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_charte_provence docs.charte;
  v_charte_archi docs.charte;
  v_doc docs.document;
  v_lib docs.library;
  v_asset_id uuid;
BEGIN
  PERFORM set_config('app.tenant_id', coalesce(current_setting('app.tenant_id', true), 'dev'), true);

  -- ── Chartes ──────────────────────────────────────────

  v_charte_provence := jsonb_populate_record(NULL::docs.charte, jsonb_build_object(
    'name', 'L''Olivier Provence',
    'description', 'Charte graphique du restaurant L''Olivier — cuisine provençale de saison',
    'color_bg', '#FAF6F1', 'color_main', '#2C1810', 'color_accent', '#C4652A',
    'color_text', '#2C1810', 'color_text_light', '#6B5D52', 'color_border', '#E8DFD4',
    'font_heading', 'Cormorant Garamond', 'font_body', 'Source Sans 3',
    'spacing_page', '15mm', 'spacing_section', '8mm', 'spacing_gap', '4mm', 'spacing_card', '6mm',
    'shadow_card', '0 1mm 4mm rgba(0,0,0,0.08)', 'radius_card', '2mm',
    'voice_formality', 'semi-formel'
  ));
  v_charte_provence.color_extra := '{"olive":"#5C6B3C","lavande":"#8B7EC8","pierre":"#D4C5A9"}'::jsonb;
  v_charte_provence.voice_personality := ARRAY['chaleureux','authentique','passionné'];
  v_charte_provence.voice_do := ARRAY['tutoyer','mots sensoriels','évoquer le terroir'];
  v_charte_provence.voice_dont := ARRAY['jargon technique','superlatifs creux'];
  v_charte_provence.voice_vocabulary := ARRAY['savoir-faire','terroir','authenticité'];
  v_charte_provence.rules := '{"color_usage":"primary = titres uniquement","photos":"pleine largeur ou 4:3"}'::jsonb;
  v_charte_provence := docs.charte_create(v_charte_provence);

  v_charte_archi := jsonb_populate_record(NULL::docs.charte, jsonb_build_object(
    'name', 'Atelier Béton',
    'description', 'Cabinet d''architecture contemporaine — béton, acier, lumière',
    'color_bg', '#FAFAFA', 'color_main', '#1A1A1A', 'color_accent', '#4A90D9',
    'color_text', '#333333', 'color_text_light', '#999999', 'color_border', '#E5E5E5',
    'font_heading', 'Space Grotesk', 'font_body', 'DM Sans',
    'spacing_page', '20mm', 'spacing_section', '12mm', 'spacing_gap', '6mm', 'spacing_card', '8mm',
    'shadow_card', '0 2px 8px rgba(0,0,0,0.06)', 'shadow_elevated', '0 8px 24px rgba(0,0,0,0.12)', 'radius_card', '0',
    'voice_formality', 'formel'
  ));
  v_charte_archi.voice_personality := ARRAY['précis','minimaliste','technique'];
  v_charte_archi.voice_do := ARRAY['vouvoyer','vocabulaire technique','références architecturales'];
  v_charte_archi.voice_dont := ARRAY['émotionnel','familier','superlatifs'];
  v_charte_archi.voice_vocabulary := ARRAY['structure','matérialité','lumière naturelle','proportion'];
  v_charte_archi.rules := '{"layout":"grille stricte 12 colonnes","photos":"noir et blanc ou désaturé"}'::jsonb;
  v_charte_archi := docs.charte_create(v_charte_archi);

  -- ── Documents ────────────────────────────────────────

  v_doc := docs.document_create(jsonb_populate_record(NULL::docs.document, jsonb_build_object(
    'name', 'Menu Printemps 2026', 'category', 'menu', 'charte_id', v_charte_provence.id
  )));
  PERFORM docs.page_set_html(v_doc.id, 0,
    '<div data-id="header" style="text-align:center;padding:var(--charte-spacing-page)">'
    || '<h1 style="font-family:var(--charte-font-heading);color:var(--charte-color-main);font-size:28pt">L''Olivier</h1>'
    || '<p style="font-family:var(--charte-font-body);color:var(--charte-color-text-light);font-size:11pt">Menu de saison — Printemps 2026</p>'
    || '</div>'
    || '<div data-id="entrees" style="padding:0 var(--charte-spacing-page)">'
    || '<h2 style="font-family:var(--charte-font-heading);color:var(--charte-color-accent);font-size:18pt;border-bottom:1px solid var(--charte-color-border)">Entrées</h2>'
    || '<p style="font-family:var(--charte-font-body);color:var(--charte-color-text)">Velouté d''asperges vertes, huile d''olive nouvelle — 14€</p>'
    || '<p style="font-family:var(--charte-font-body);color:var(--charte-color-text)">Tartare de bar, agrumes et fenouil — 16€</p>'
    || '<p style="font-family:var(--charte-font-body);color:var(--charte-color-text)">Salade de chèvre chaud, miel de lavande — 13€</p>'
    || '</div>'
    || '<div data-id="plats" style="padding:0 var(--charte-spacing-page)">'
    || '<h2 style="font-family:var(--charte-font-heading);color:var(--charte-color-accent);font-size:18pt;border-bottom:1px solid var(--charte-color-border)">Plats</h2>'
    || '<p style="font-family:var(--charte-font-body);color:var(--charte-color-text)">Agneau de Sisteron rôti, jus au thym — 28€</p>'
    || '<p style="font-family:var(--charte-font-body);color:var(--charte-color-text)">Loup en croûte de sel, ratatouille — 32€</p>'
    || '</div>'
  );
  PERFORM docs.page_add(v_doc.id, 'Desserts & Vins',
    '<div data-id="desserts" style="padding:var(--charte-spacing-page)">'
    || '<h2 style="font-family:var(--charte-font-heading);color:var(--charte-color-accent);font-size:18pt;border-bottom:1px solid var(--charte-color-border)">Desserts</h2>'
    || '<p style="font-family:var(--charte-font-body);color:var(--charte-color-text)">Tarte au citron meringuée — 10€</p>'
    || '<p style="font-family:var(--charte-font-body);color:var(--charte-color-text)">Calisson glacé, coulis d''abricot — 12€</p>'
    || '</div>'
  );

  v_doc := docs.document_create(jsonb_populate_record(NULL::docs.document, jsonb_build_object(
    'name', 'Carte de visite', 'category', 'identite', 'format', 'A5', 'orientation', 'landscape',
    'charte_id', v_charte_archi.id
  )));
  PERFORM docs.page_set_html(v_doc.id, 0,
    '<div data-id="card" style="display:flex;height:100%;align-items:center;justify-content:space-between;padding:var(--charte-spacing-page)">'
    || '<div data-id="left">'
    || '<h1 style="font-family:var(--charte-font-heading);color:var(--charte-color-main);font-size:24pt;margin:0">ATELIER BÉTON</h1>'
    || '<p style="font-family:var(--charte-font-body);color:var(--charte-color-text-light);font-size:9pt;letter-spacing:2px;margin:4mm 0 0">ARCHITECTURE CONTEMPORAINE</p>'
    || '</div>'
    || '<div data-id="right" style="text-align:right;font-family:var(--charte-font-body);color:var(--charte-color-text);font-size:9pt;line-height:1.8">'
    || '<p style="margin:0">Marie Dupont, architecte DPLG</p>'
    || '<p style="margin:0;color:var(--charte-color-accent)">m.dupont@atelierbeton.fr</p>'
    || '<p style="margin:0">04 90 12 34 56</p>'
    || '</div>'
    || '</div>'
  );

  v_doc := docs.document_create(jsonb_populate_record(NULL::docs.document, jsonb_build_object(
    'name', 'Soirée Vendanges', 'category', 'evenement', 'format', 'A3',
    'charte_id', v_charte_provence.id
  )));
  PERFORM docs.page_set_html(v_doc.id, 0,
    '<div data-id="poster" style="text-align:center;padding:var(--charte-spacing-page);background:var(--charte-color-bg)">'
    || '<h1 style="font-family:var(--charte-font-heading);color:var(--charte-color-main);font-size:48pt;margin-bottom:8mm">Soirée Vendanges</h1>'
    || '<p style="font-family:var(--charte-font-body);color:var(--charte-color-accent);font-size:18pt">Samedi 20 septembre 2026</p>'
    || '<p style="font-family:var(--charte-font-body);color:var(--charte-color-text);font-size:14pt;margin-top:12mm">Dîner sous les oliviers · Musique live · Dégustation</p>'
    || '<p style="font-family:var(--charte-font-body);color:var(--charte-color-text-light);font-size:11pt;margin-top:8mm">Restaurant L''Olivier — Chemin des Collines, Gordes</p>'
    || '</div>'
  );

  -- ── Library ──────────────────────────────────────────

  v_lib := docs.library_create(jsonb_populate_record(NULL::docs.library, jsonb_build_object(
    'name', 'Photos L''Olivier', 'description', 'Photothèque du restaurant — terrasse, plats, ambiance'
  )));

  FOR v_asset_id IN SELECT id FROM asset.asset LIMIT 3
  LOOP
    PERFORM docs.library_add_asset(v_lib.id, v_asset_id, 'ambiance', 'Photo d''ambiance restaurant');
  END LOOP;

END;
$function$;
