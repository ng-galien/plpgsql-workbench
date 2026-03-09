-- Docman: Document classification system
-- Depends on: docstore.file (path PK)

CREATE SCHEMA IF NOT EXISTS docman;

--------------------------------------------------------------------------------
-- Label: taxonomy tree (categories) + flat tags
--------------------------------------------------------------------------------
CREATE TABLE docman.label (
  id          SERIAL PRIMARY KEY,
  name        TEXT NOT NULL,
  kind        TEXT NOT NULL DEFAULT 'tag'
              CHECK (kind IN ('category', 'tag')),
  parent_id   INT REFERENCES docman.label(id),
  description TEXT,
  aliases     TEXT[] DEFAULT '{}',
  UNIQUE (name, kind, parent_id)
);

CREATE INDEX idx_label_kind ON docman.label(kind);

--------------------------------------------------------------------------------
-- Entity: business actors (client, fournisseur, projet, banque...)
--------------------------------------------------------------------------------
CREATE TABLE docman.entity (
  id       SERIAL PRIMARY KEY,
  kind     TEXT NOT NULL,
  name     TEXT NOT NULL,
  aliases  TEXT[] DEFAULT '{}',
  metadata JSONB DEFAULT '{}',
  UNIQUE (kind, name)
);

CREATE INDEX idx_entity_kind ON docman.entity(kind);

--------------------------------------------------------------------------------
-- Document: business card of a physical file
--------------------------------------------------------------------------------
CREATE TABLE docman.document (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  file_path     TEXT NOT NULL UNIQUE REFERENCES docstore.file(path),
  doc_type      TEXT,
  document_date DATE,
  source        TEXT NOT NULL DEFAULT 'filesystem'
                CHECK (source IN ('filesystem', 'email')),
  source_ref    TEXT,
  summary       TEXT,
  summary_tsv   TSVECTOR GENERATED ALWAYS AS (
                  to_tsvector('french', coalesce(summary, ''))
                ) STORED,
  classified_at TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_doc_summary_fts ON docman.document USING gin(summary_tsv);
CREATE INDEX idx_doc_type ON docman.document(doc_type);
CREATE INDEX idx_doc_date ON docman.document(document_date);
CREATE INDEX idx_doc_source ON docman.document(source);

--------------------------------------------------------------------------------
-- Document <-> Label (N:N with classification metadata)
--------------------------------------------------------------------------------
CREATE TABLE docman.document_label (
  document_id UUID NOT NULL REFERENCES docman.document(id) ON DELETE CASCADE,
  label_id    INT  NOT NULL REFERENCES docman.label(id) ON DELETE CASCADE,
  confidence  REAL DEFAULT 1.0,
  assigned_by TEXT DEFAULT 'agent' CHECK (assigned_by IN ('agent', 'user')),
  assigned_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (document_id, label_id)
);

--------------------------------------------------------------------------------
-- Document <-> Entity (N:N with role and classification metadata)
--------------------------------------------------------------------------------
CREATE TABLE docman.document_entity (
  document_id UUID NOT NULL REFERENCES docman.document(id) ON DELETE CASCADE,
  entity_id   INT  NOT NULL REFERENCES docman.entity(id) ON DELETE CASCADE,
  role        TEXT NOT NULL,
  confidence  REAL DEFAULT 1.0,
  assigned_by TEXT DEFAULT 'agent' CHECK (assigned_by IN ('agent', 'user')),
  assigned_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (document_id, entity_id, role)
);

--------------------------------------------------------------------------------
-- Document <-> Document (directed graph with classification metadata)
--------------------------------------------------------------------------------
CREATE TABLE docman.document_relation (
  source_id   UUID NOT NULL REFERENCES docman.document(id) ON DELETE CASCADE,
  target_id   UUID NOT NULL REFERENCES docman.document(id) ON DELETE CASCADE,
  kind        TEXT NOT NULL,
  confidence  REAL DEFAULT 1.0,
  assigned_by TEXT DEFAULT 'agent' CHECK (assigned_by IN ('agent', 'user')),
  assigned_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (source_id, target_id, kind),
  CHECK (source_id <> target_id)
);
