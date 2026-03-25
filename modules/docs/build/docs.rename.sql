-- Wave 3: charte → charter + company columns + category values
ALTER TABLE docs.charte RENAME TO charter;
ALTER TABLE docs.charte_revision RENAME TO charter_revision;
ALTER TABLE docs.document RENAME COLUMN charte_id TO charter_id;
ALTER TABLE docs.charter_revision RENAME COLUMN charte_id TO charter_id;
ALTER TABLE docs.company RENAME COLUMN siret TO tax_id;
ALTER TABLE docs.company RENAME COLUMN tva_intra TO vat_number;
ALTER TABLE docs.company RENAME COLUMN mentions TO legal_notices;
UPDATE docs.document SET category = 'identity' WHERE category = 'identite';
UPDATE docs.document SET category = 'event' WHERE category = 'evenement';
