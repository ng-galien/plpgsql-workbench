-- Fix default values after English rename
ALTER TABLE quote.estimate ALTER COLUMN status SET DEFAULT 'draft';
ALTER TABLE quote.invoice ALTER COLUMN status SET DEFAULT 'draft';
