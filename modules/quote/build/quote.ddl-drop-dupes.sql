-- Fix: drop empty duplicate tables created by re-applied quote.ddl.sql
-- Data lives in the renamed tables (estimate, invoice, line_item, legal_notice)
DROP TABLE IF EXISTS quote.ligne CASCADE;
DROP TABLE IF EXISTS quote.facture CASCADE;
DROP TABLE IF EXISTS quote.devis CASCADE;
DROP TABLE IF EXISTS quote.mention CASCADE;
