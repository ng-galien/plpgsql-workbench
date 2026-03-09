CREATE SCHEMA IF NOT EXISTS banking;
CREATE SCHEMA IF NOT EXISTS banking_ut;

CREATE TABLE IF NOT EXISTS banking.accounts (
  id serial PRIMARY KEY,
  owner text NOT NULL,
  balance numeric(12,2) NOT NULL DEFAULT 0 CHECK (balance >= 0)
);

CREATE TABLE IF NOT EXISTS banking.transactions (
  id serial PRIMARY KEY,
  from_account_id integer REFERENCES banking.accounts(id),
  to_account_id integer REFERENCES banking.accounts(id),
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  created_at timestamptz DEFAULT now()
);
