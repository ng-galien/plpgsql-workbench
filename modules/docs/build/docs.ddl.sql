-- document — DDL (v2: XHTML composition engine)

CREATE SCHEMA IF NOT EXISTS docs;
CREATE SCHEMA IF NOT EXISTS docs_ut;
CREATE SCHEMA IF NOT EXISTS docs_qa;

-- ────────────────────────────────────────────────────────
-- Charte (design tokens, voice, rules)
-- ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS docs.charte (
  id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  tenant_id         text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  name              text NOT NULL,
  description       text,

  -- Color socle (obligatoire — le design system minimum)
  color_bg          text NOT NULL,
  color_main        text NOT NULL,
  color_accent      text NOT NULL,
  color_text        text NOT NULL,
  color_text_light  text NOT NULL,
  color_border      text NOT NULL,
  color_extra       jsonb NOT NULL DEFAULT '{}',

  -- Font (obligatoire)
  font_heading      text NOT NULL,
  font_body         text NOT NULL,

  -- Spacing
  spacing_page      text,
  spacing_section   text,
  spacing_gap       text,
  spacing_card      text,

  -- Shadow
  shadow_card       text,
  shadow_elevated   text,

  -- Radius
  radius_card       text,

  -- Voice
  voice_personality text[],
  voice_formality   text,
  voice_do          text[],
  voice_dont        text[],
  voice_vocabulary  text[],
  voice_examples    jsonb,

  -- Rules (libre)
  rules             jsonb NOT NULL DEFAULT '{}',

  created_at        timestamptz DEFAULT now(),
  updated_at        timestamptz DEFAULT now(),

  UNIQUE (tenant_id, name)
);

CREATE INDEX IF NOT EXISTS idx_charte_tenant ON docs.charte (tenant_id);

COMMENT ON TABLE docs.charte IS 'Design tokens — identité visuelle (couleurs, fonts, spacing, voice, rules)';
COMMENT ON COLUMN docs.charte.color_bg IS 'Fond de page — 60% de la surface, neutre';
COMMENT ON COLUMN docs.charte.color_main IS 'Couleur signature — 30%, titres et éléments structurants';
COMMENT ON COLUMN docs.charte.color_accent IS 'CTA et highlights — 10%, contraste fort avec main';
COMMENT ON COLUMN docs.charte.color_text IS 'Corps de texte — jamais noir pur, ratio contraste 4.5:1 min avec bg';
COMMENT ON COLUMN docs.charte.color_text_light IS 'Texte secondaire — 40-60% opacité du text';
COMMENT ON COLUMN docs.charte.color_border IS 'Séparateurs — subtil, 10-20% opacité du main';
COMMENT ON COLUMN docs.charte.color_extra IS 'Tokens couleur libres — noms évocateurs du domaine (ocean, olive, terracotta)';
COMMENT ON COLUMN docs.charte.font_heading IS 'Font titres — Google Font name';
COMMENT ON COLUMN docs.charte.font_body IS 'Font corps de texte — Google Font name';
COMMENT ON COLUMN docs.charte.voice_personality IS 'Traits de personnalité de la marque';
COMMENT ON COLUMN docs.charte.voice_formality IS 'Niveau de formalité (informel, semi-formel, formel)';
COMMENT ON COLUMN docs.charte.rules IS 'Contraintes design libres — ce qu''on ne doit PAS faire avec cette charte';

CREATE TABLE IF NOT EXISTS docs.charte_revision (
  charte_id   text NOT NULL REFERENCES docs.charte(id) ON DELETE CASCADE,
  version     integer NOT NULL,
  tokens      jsonb NOT NULL,
  created_at  timestamptz DEFAULT now(),
  PRIMARY KEY (charte_id, version)
);

COMMENT ON TABLE docs.charte_revision IS 'Historique des tokens de charte (snapshot à chaque modification)';

-- ────────────────────────────────────────────────────────
-- Émetteur (entreprise — pré-requis pour factures/devis)
-- ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS docs.company (
  id            serial PRIMARY KEY,
  tenant_id     text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  name          text NOT NULL,
  siret         text,
  tva_intra     text,
  address       text,
  city          text,
  postal_code   text,
  phone         text,
  email         text,
  website       text,
  logo_asset_id uuid,
  mentions      text,
  created_at    timestamptz DEFAULT now(),
  UNIQUE (tenant_id)
);

COMMENT ON TABLE docs.company IS 'Émetteur (entreprise) — informations légales pour factures/devis';

-- ────────────────────────────────────────────────────────
-- Document (composition XHTML)
-- ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS docs.document (
  id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  tenant_id       text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  name            text NOT NULL,
  category        text NOT NULL DEFAULT 'general',
  charte_id       text REFERENCES docs.charte(id) ON DELETE SET NULL,

  -- Canvas
  format          text NOT NULL DEFAULT 'A4'
                  CHECK (format IN ('A2','A3','A4','A5','HD','MACBOOK','IPAD','MOBILE','CUSTOM')),
  orientation     text NOT NULL DEFAULT 'portrait'
                  CHECK (orientation IN ('portrait','landscape')),
  width           numeric NOT NULL DEFAULT 210,
  height          numeric NOT NULL DEFAULT 297,
  bg              text NOT NULL DEFAULT '#ffffff',
  text_margin     numeric NOT NULL DEFAULT 10,

  -- Meta
  design_notes    text,
  team_notes      text,
  rating          smallint DEFAULT 0 CHECK (rating BETWEEN 0 AND 5),

  -- Email
  email_to        text,
  email_cc        text,
  email_bcc       text,
  email_subject   text,

  -- Référence externe (ex: devis, facture)
  ref_module      text,
  ref_id          text,
  status          text DEFAULT 'draft'
                  CHECK (status IN ('draft','generated','signed','archived')),

  -- Pagination
  active_page     integer NOT NULL DEFAULT 0,

  created_at      timestamptz DEFAULT now(),
  updated_at      timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_doc_tenant ON docs.document (tenant_id);
CREATE INDEX IF NOT EXISTS idx_doc_category ON docs.document (tenant_id, category);
CREATE INDEX IF NOT EXISTS idx_doc_charte ON docs.document (charte_id) WHERE charte_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_doc_ref ON docs.document (ref_module, ref_id) WHERE ref_module IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_doc_status ON docs.document (tenant_id, status);

COMMENT ON TABLE docs.document IS 'Document XHTML multi-pages avec canvas dimensionné';
COMMENT ON COLUMN docs.document.format IS 'Format du canvas (A2, A3, A4, A5, HD, MACBOOK, IPAD, MOBILE, CUSTOM)';
COMMENT ON COLUMN docs.document.orientation IS 'Orientation (portrait, landscape)';
COMMENT ON COLUMN docs.document.width IS 'Largeur en mm (print) ou px (screen)';
COMMENT ON COLUMN docs.document.height IS 'Hauteur en mm (print) ou px (screen)';
COMMENT ON COLUMN docs.document.charte_id IS 'Charte graphique liée — les tokens visuels du document';
COMMENT ON COLUMN docs.document.library_id IS 'Photothèque liée — les images disponibles pour la composition';
COMMENT ON COLUMN docs.document.status IS 'Cycle de vie : draft → generated → signed → archived';
COMMENT ON COLUMN docs.document.ref_module IS 'Module source (quote, crm...) pour les documents liés';
COMMENT ON COLUMN docs.document.ref_id IS 'ID de la ressource source dans le module';

-- ────────────────────────────────────────────────────────
-- Page (XHTML content per page)
-- ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS docs.page (
  doc_id        text NOT NULL REFERENCES docs.document(id) ON DELETE CASCADE,
  page_index    integer NOT NULL,
  name          text NOT NULL DEFAULT 'Page 1',
  html          text NOT NULL DEFAULT '',

  -- Per-page canvas override (NULL = inherit from document)
  format        text,
  orientation   text,
  width         numeric,
  height        numeric,
  bg            text,
  text_margin   numeric,

  PRIMARY KEY (doc_id, page_index)
);

COMMENT ON TABLE docs.page IS 'Page XHTML d''un document — contenu + override canvas optionnel';

CREATE TABLE IF NOT EXISTS docs.page_revision (
  doc_id        text NOT NULL,
  page_index    integer NOT NULL,
  version       integer NOT NULL,
  html          text NOT NULL,
  created_at    timestamptz DEFAULT now(),
  PRIMARY KEY (doc_id, page_index, version)
);

COMMENT ON TABLE docs.page_revision IS 'Historique HTML par page (snapshot à chaque modification)';

-- ────────────────────────────────────────────────────────
-- Session (ephemeral workspace state — UNLOGGED, zero WAL)
-- One row per user: tracks the entire workspace (multi-doc canvas)
-- ────────────────────────────────────────────────────────

DROP TABLE IF EXISTS docs.session;
CREATE UNLOGGED TABLE docs.session (
  user_id             text NOT NULL DEFAULT current_setting('app.user_id', true),
  tenant_id           text NOT NULL DEFAULT current_setting('app.tenant_id', true),

  -- Workspace (what's open on the infinite canvas)
  workspace_docs      text[] NOT NULL DEFAULT '{}',
  focused_doc         text,

  -- Pending messages queued for Claude
  pending             jsonb NOT NULL DEFAULT '[]',

  -- View state
  zoom                real NOT NULL DEFAULT 100,
  pan_x               real NOT NULL DEFAULT 0,
  pan_y               real NOT NULL DEFAULT 0,

  -- Preferences
  bar_position        text NOT NULL DEFAULT 'bottom' CHECK (bar_position IN ('top', 'bottom')),
  dark_mode           boolean NOT NULL DEFAULT false,

  updated_at          timestamptz DEFAULT now(),
  PRIMARY KEY (tenant_id, user_id)
);

COMMENT ON TABLE docs.session IS 'État workspace éphémère (UNLOGGED) — docs ouverts, zoom, pan';

-- ────────────────────────────────────────────────────────
-- Library (curated asset selection for composition)
-- ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS docs.library (
  id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  tenant_id   text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  name        text NOT NULL,
  description text,
  created_at  timestamptz DEFAULT now(),
  UNIQUE (tenant_id, name)
);

CREATE INDEX IF NOT EXISTS idx_library_tenant ON docs.library (tenant_id);

COMMENT ON TABLE docs.library IS 'Photothèque — sélection curatée d''assets pour la composition';

CREATE TABLE IF NOT EXISTS docs.library_asset (
  library_id  text NOT NULL REFERENCES docs.library(id) ON DELETE CASCADE,
  asset_id    uuid NOT NULL REFERENCES asset.asset(id) ON DELETE CASCADE,
  role        text,
  context     text,
  sort_order  integer DEFAULT 0,
  PRIMARY KEY (library_id, asset_id)
);

COMMENT ON TABLE docs.library_asset IS 'Association library ↔ asset avec rôle et contexte';
COMMENT ON COLUMN docs.library_asset.role IS 'Rôle dans la composition (hero, portrait, logo, texture, ambiance, produit)';
COMMENT ON COLUMN docs.library_asset.context IS 'Description de l''image dans le contexte du projet';

ALTER TABLE docs.document
  ADD COLUMN IF NOT EXISTS library_id text REFERENCES docs.library(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_doc_library ON docs.document (library_id) WHERE library_id IS NOT NULL;

-- ────────────────────────────────────────────────────────
-- RLS
-- ────────────────────────────────────────────────────────

ALTER TABLE docs.charte ENABLE ROW LEVEL SECURITY;
ALTER TABLE docs.document ENABLE ROW LEVEL SECURITY;
ALTER TABLE docs.company ENABLE ROW LEVEL SECURITY;
ALTER TABLE docs.library ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'docs.charte'::regclass AND polname = 'tenant_isolation') THEN
    CREATE POLICY tenant_isolation ON docs.charte FOR ALL USING (tenant_id = current_setting('app.tenant_id', true));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'docs.document'::regclass AND polname = 'tenant_isolation') THEN
    CREATE POLICY tenant_isolation ON docs.document FOR ALL USING (tenant_id = current_setting('app.tenant_id', true));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'docs.company'::regclass AND polname = 'tenant_isolation') THEN
    CREATE POLICY tenant_isolation ON docs.company FOR ALL USING (tenant_id = current_setting('app.tenant_id', true));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'docs.library'::regclass AND polname = 'tenant_isolation') THEN
    CREATE POLICY tenant_isolation ON docs.library FOR ALL USING (tenant_id = current_setting('app.tenant_id', true));
  END IF;
END $$;
