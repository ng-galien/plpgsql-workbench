-- planning — DDL

CREATE SCHEMA IF NOT EXISTS planning;
CREATE SCHEMA IF NOT EXISTS planning_ut;
CREATE SCHEMA IF NOT EXISTS planning_qa;
GRANT USAGE ON SCHEMA planning TO anon;

-- Intervenants (equipe : ouvriers, sous-traitants, chefs d'equipe)
CREATE TABLE IF NOT EXISTS planning.intervenant (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  nom text NOT NULL,
  role text NOT NULL DEFAULT '',                -- ex: charpentier, electricien
  telephone text,
  couleur text NOT NULL DEFAULT '#3b82f6',      -- couleur agenda (hex)
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_intervenant_tenant ON planning.intervenant(tenant_id);
CREATE INDEX IF NOT EXISTS idx_intervenant_actif ON planning.intervenant(actif, nom);

-- Evenements (creneaux planifies — lies ou non a un chantier)
CREATE TABLE IF NOT EXISTS planning.evenement (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  titre text NOT NULL,
  type text NOT NULL DEFAULT 'chantier' CHECK (type IN ('chantier', 'livraison', 'reunion', 'conge', 'autre')),
  chantier_id int REFERENCES project.chantier(id) ON DELETE SET NULL,
  date_debut date NOT NULL,
  date_fin date NOT NULL,
  heure_debut time DEFAULT '08:00',
  heure_fin time DEFAULT '17:00',
  lieu text NOT NULL DEFAULT '',
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_dates CHECK (date_fin >= date_debut)
);

CREATE INDEX IF NOT EXISTS idx_evenement_tenant ON planning.evenement(tenant_id);
CREATE INDEX IF NOT EXISTS idx_evenement_dates ON planning.evenement(date_debut, date_fin);
CREATE INDEX IF NOT EXISTS idx_evenement_chantier ON planning.evenement(chantier_id);

-- Affectations (lien intervenant <-> evenement)
CREATE TABLE IF NOT EXISTS planning.affectation (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  evenement_id int NOT NULL REFERENCES planning.evenement(id) ON DELETE CASCADE,
  intervenant_id int NOT NULL REFERENCES planning.intervenant(id) ON DELETE CASCADE,
  UNIQUE(evenement_id, intervenant_id)
);

CREATE INDEX IF NOT EXISTS idx_affectation_tenant ON planning.affectation(tenant_id);
CREATE INDEX IF NOT EXISTS idx_affectation_evenement ON planning.affectation(evenement_id);
CREATE INDEX IF NOT EXISTS idx_affectation_intervenant ON planning.affectation(intervenant_id);

-- Row Level Security
ALTER TABLE planning.intervenant ENABLE ROW LEVEL SECURITY;
ALTER TABLE planning.evenement ENABLE ROW LEVEL SECURITY;
ALTER TABLE planning.affectation ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_isolation ON planning.intervenant;
CREATE POLICY tenant_isolation ON planning.intervenant
  USING (tenant_id = current_setting('app.tenant_id', true));
DROP POLICY IF EXISTS tenant_isolation ON planning.evenement;
CREATE POLICY tenant_isolation ON planning.evenement
  USING (tenant_id = current_setting('app.tenant_id', true));
DROP POLICY IF EXISTS tenant_isolation ON planning.affectation;
CREATE POLICY tenant_isolation ON planning.affectation
  USING (tenant_id = current_setting('app.tenant_id', true));

-- Permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON planning.intervenant TO anon;
GRANT USAGE ON SEQUENCE planning.intervenant_id_seq TO anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON planning.evenement TO anon;
GRANT USAGE ON SEQUENCE planning.evenement_id_seq TO anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON planning.affectation TO anon;
GRANT USAGE ON SEQUENCE planning.affectation_id_seq TO anon;

GRANT USAGE ON SCHEMA planning_ut TO anon;
GRANT USAGE ON SCHEMA planning_qa TO anon;

-- Default privileges
ALTER DEFAULT PRIVILEGES IN SCHEMA planning GRANT EXECUTE ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA planning_ut GRANT EXECUTE ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA planning_qa GRANT EXECUTE ON FUNCTIONS TO anon;
