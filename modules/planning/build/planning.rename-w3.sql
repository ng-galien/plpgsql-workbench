-- Wave 3: Language rename French → English

-- Drop CHECK constraints before rename
ALTER TABLE planning.evenement DROP CONSTRAINT IF EXISTS evenement_type_check;
ALTER TABLE planning.evenement DROP CONSTRAINT IF EXISTS chk_dates;

-- Rename tables
ALTER TABLE planning.intervenant RENAME TO worker;
ALTER TABLE planning.evenement RENAME TO event;
ALTER TABLE planning.affectation RENAME TO assignment;

-- Rename columns: worker
ALTER TABLE planning.worker RENAME COLUMN nom TO name;
ALTER TABLE planning.worker RENAME COLUMN telephone TO phone;
ALTER TABLE planning.worker RENAME COLUMN couleur TO color;
ALTER TABLE planning.worker RENAME COLUMN actif TO active;

-- Rename columns: event
ALTER TABLE planning.event RENAME COLUMN titre TO title;
ALTER TABLE planning.event RENAME COLUMN chantier_id TO project_id;
ALTER TABLE planning.event RENAME COLUMN date_debut TO start_date;
ALTER TABLE planning.event RENAME COLUMN date_fin TO end_date;
ALTER TABLE planning.event RENAME COLUMN heure_debut TO start_time;
ALTER TABLE planning.event RENAME COLUMN heure_fin TO end_time;
ALTER TABLE planning.event RENAME COLUMN lieu TO location;

-- Rename columns: assignment
ALTER TABLE planning.assignment RENAME COLUMN evenement_id TO event_id;
ALTER TABLE planning.assignment RENAME COLUMN intervenant_id TO worker_id;

-- Update type values
UPDATE planning.event SET type = 'job_site' WHERE type = 'chantier';
UPDATE planning.event SET type = 'delivery' WHERE type = 'livraison';
UPDATE planning.event SET type = 'meeting' WHERE type = 'reunion';
UPDATE planning.event SET type = 'leave' WHERE type = 'conge';
UPDATE planning.event SET type = 'other' WHERE type = 'autre';

-- New CHECK constraints
ALTER TABLE planning.event ADD CONSTRAINT event_type_check CHECK (type IN ('job_site', 'delivery', 'meeting', 'leave', 'other'));
ALTER TABLE planning.event ADD CONSTRAINT chk_dates CHECK (end_date >= start_date);

-- Rename indexes
ALTER INDEX IF EXISTS planning.idx_intervenant_tenant RENAME TO idx_worker_tenant;
ALTER INDEX IF EXISTS planning.idx_intervenant_actif RENAME TO idx_worker_active;
ALTER INDEX IF EXISTS planning.idx_evenement_tenant RENAME TO idx_event_tenant;
ALTER INDEX IF EXISTS planning.idx_evenement_dates RENAME TO idx_event_dates;
ALTER INDEX IF EXISTS planning.idx_evenement_chantier RENAME TO idx_event_project;
ALTER INDEX IF EXISTS planning.idx_affectation_tenant RENAME TO idx_assignment_tenant;
ALTER INDEX IF EXISTS planning.idx_affectation_evenement RENAME TO idx_assignment_event;
ALTER INDEX IF EXISTS planning.idx_affectation_intervenant RENAME TO idx_assignment_worker;
