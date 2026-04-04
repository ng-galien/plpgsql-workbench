CREATE SCHEMA IF NOT EXISTS i18n;

CREATE TABLE IF NOT EXISTS i18n.translation (
  lang text NOT NULL,
  key text NOT NULL,
  value text NOT NULL,
  PRIMARY KEY (lang, key)
);
