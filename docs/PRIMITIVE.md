# PL/pgSQL Workbench — Primitives

> L'agent interagit avec des **ressources** (get/set) et des **actions** (deploy, test...).
> Tout le reste — filesystem, deploy_state, git — est de la plomberie invisible.

## Ressources : `get` / `set`

L'agent navigue et modifie un arbre de ressources via des URIs.
Format de sortie compact, optimise pour le scan LLM.

### `get`

Lit une ressource.

**`get plpgsql://`** — catalogue :
```
bank           3 tables, 5 functions, 1 trigger
api            0 tables, 12 functions, 0 triggers
api_persist    0 tables, 8 functions, 0 triggers
```

**`get plpgsql://bank`** — schema :
```
tables:
  accounts (id integer PK, owner_id integer FK→customers.id, balance numeric, created_at timestamptz)
  transactions (id integer PK, from_id integer FK→accounts.id, to_id integer FK→accounts.id, amount numeric, ts timestamptz)
  customers (id integer PK, name text, email text)

functions:
  transfer(from_account integer, to_account integer, amount numeric) → void
  get_balance(account_id integer) → numeric
  create_account(owner_id integer, initial numeric) → integer
  log_transaction(from_id integer, to_id integer, amount numeric) → void
  batch_transfer(transfers jsonb) → void

triggers:
  audit_on_transfer ON transactions AFTER INSERT → log_audit()
```

**`get plpgsql://bank/function/transfer`** — fonction :
```
bank.transfer(from_account integer, to_account integer, amount numeric) → void
  vars: v_balance numeric, v_from record, v_to record
  calls: get_balance, log_transaction
  callers: batch_transfer, process_payment
  tables: accounts(RW), transactions(W)
  body:
    BEGIN
      v_balance := bank.get_balance(from_account);
      IF v_balance < amount THEN
        RAISE EXCEPTION 'Insufficient funds: % < %', v_balance, amount;
      END IF;
      UPDATE bank.accounts SET balance = balance - amount WHERE id = from_account;
      UPDATE bank.accounts SET balance = balance + amount WHERE id = to_account;
      PERFORM bank.log_transaction(from_account, to_account, amount);
    END;
```

**`get plpgsql://bank/table/accounts`** — table :
```
bank.accounts
  id          integer       PK
  owner_id    integer       FK → customers.id
  balance     numeric       NOT NULL DEFAULT 0
  created_at  timestamptz   DEFAULT now()
  indexes: accounts_owner_idx (owner_id)
  used_by: transfer(RW), get_balance(R), create_account(W)
```

**`get plpgsql://bank/trigger/audit_on_transfer`** — trigger :
```
bank.audit_on_transfer
  table: bank.transactions
  event: AFTER INSERT
  function: bank.log_audit()
  for_each: ROW
```

**`get plpgsql://api/type/call_result`** — type :
```
api.call_result (composite)
  result_code     integer
  result_message  text
  result_data     jsonb
  used_by: api.call
```

---

### `set`

Ecrit une ressource **et la valide automatiquement**.

La validation depend du type de ressource :
- **Function/Procedure** → `plpgsql_check` automatique
- **DDL (table, type, enum)** → dry-run transaction (BEGIN → execute → ROLLBACK)
- **Trigger** → dry-run transaction

L'agent obtient un feedback instantane a chaque ecriture.

**`set plpgsql://bank/function/get_client_balance`** — creer une fonction :
```
input:
  CREATE OR REPLACE FUNCTION bank.get_client_balance(p_client_id integer)
  RETURNS numeric
  LANGUAGE plpgsql
  AS $$
  DECLARE
    v_total numeric;
  BEGIN
    SELECT COALESCE(sum(balance), 0) INTO v_total
    FROM bank.accounts WHERE owner_id = p_client_id;
    RETURN v_total;
  END;
  $$;

output:
  ✓ plpgsql_check passed
  resource: plpgsql://bank/function/get_client_balance
```

**`set plpgsql://bank/function/transfer`** — modifier une fonction existante :
```
input:
  CREATE OR REPLACE FUNCTION bank.transfer(...)
  ...
  $$;

output:
  ✓ plpgsql_check passed
  resource: plpgsql://bank/function/transfer [modified]
```

**`set` avec erreur** :
```
input:
  CREATE OR REPLACE FUNCTION bank.bad_function(...)
  ...
  SELECT * FROM bank.nonexistent_table;
  ...
  $$;

output:
  ✗ plpgsql_check failed
  line 5: relation "bank.nonexistent_table" does not exist
```

**`set plpgsql://bank/table/audit_log`** — creer une table :
```
input:
  CREATE TABLE IF NOT EXISTS bank.audit_log (
    id          serial PRIMARY KEY,
    account_id  integer REFERENCES bank.accounts(id),
    amount      numeric NOT NULL,
    logged_at   timestamptz DEFAULT now()
  );

output:
  ✓ dry-run passed (transaction rolled back)
  resource: plpgsql://bank/table/audit_log
```

**`set` DDL avec erreur** :
```
input:
  CREATE TABLE IF NOT EXISTS bank.audit_log (
    account_id  integer REFERENCES bank.nonexistent(id)
  );

output:
  ✗ dry-run failed
  relation "bank.nonexistent" does not exist
```

---

## Actions

### `deploy`

Pousse les ressources modifiees (via `set`) en base.

**Input** :
| Param | Type | Defaut | Description |
|---|---|---|---|
| `target` | string[]? | toutes les modifiees | URIs specifiques |
| `dry_run` | boolean | false | Afficher le plan sans executer |

**Output** :
```
plan:
  1. [ddl]       bank/audit_log           new
  2. [function]  bank/log_audit           new
  3. [function]  bank/transfer            modified
  4. [function]  bank/get_client_balance   new
  5. [trigger]   bank/audit_on_transfer   new
  6. [migration] 003-backfill-emails      new

executed: 6/6
errors: none
```

En cas d'erreur (best-effort) :
```
  1. [ddl]       bank/audit_log           new        ✓
  2. [function]  bank/log_audit           new        ✓
  3. [function]  bank/transfer            modified   ✗ ERROR
  4. [trigger]   bank/audit_on_transfer   new        skipped (depends on 3)

executed: 2/4, errors: 1
  bank/transfer line 12: column "balancee" does not exist
```

L'ordre de deploiement est calcule automatiquement (DDL → Functions → Triggers → Migrations).

---

### `test`

Execute les tests pgTAP.

**Input** :
| Param | Type | Defaut | Description |
|---|---|---|---|
| `schema` | string? | tous | Filtrer par schema |
| `function` | string? | toutes | Tests pour une fonction |

**Output** :
```
tests/bank/transfer.test.sql
  ✓ 1 - has_function bank.transfer
  ✓ 2 - Transfer reduces source balance
  ✓ 3 - Transfer increases target balance
  ✗ 4 - Transfer fails on insufficient funds
        got: no exception raised
        expected: RAISE EXCEPTION

tests/bank/get_balance.test.sql
  ✓ 1 - Returns balance for existing account
  ✓ 2 - Returns 0 for non-existent account

passed: 5/6, failed: 1
```

---

### `coverage`

Couverture de code via piggly.

**Input** :
| Param | Type | Defaut | Description |
|---|---|---|---|
| `schema` | string? | tous | Filtrer par schema |

**Output** :
```
bank.transfer          87%  (13/15 lines)  ██████████░░
bank.get_balance      100%  (8/8 lines)    ████████████
bank.create_account    72%  (13/18 lines)  █████████░░░
bank.log_audit        100%  (5/5 lines)    ████████████

total: 84% (39/46 lines)
threshold: 80% ✓
```

---

### `query`

Execute du SQL sur la connexion active.

**Input** :
| Param | Type | Defaut | Description |
|---|---|---|---|
| `sql` | string | requis | Statement SQL |

**Output** :
```
 id | name    | balance
----+---------+---------
  1 | alice   | 1234.56
  2 | bob     |  567.89
(2 rows, 12ms)
```

---

### `rollback`

Annule les N dernieres migrations.

**Input** :
| Param | Type | Defaut | Description |
|---|---|---|---|
| `count` | number | 1 | Nombre de migrations |

**Output** :
```
rolled back:
  003-backfill-emails      ✓ down.sql executed
  002-seed-initial-data    ✓ down.sql executed

rolled back: 2 migrations
```

---

## Resume

7 primitives :

| Primitive | Role | Validation |
|---|---|---|
| `get` | Lire une ressource | — |
| `set` | Ecrire une ressource | Auto : plpgsql_check (functions) ou dry-run tx (DDL) |
| `deploy` | Pousser en base | Ordre de dependances automatique |
| `test` | Tests pgTAP | — |
| `coverage` | Couverture piggly | Seuil configurable |
| `query` | SQL libre | — |
| `rollback` | Annuler des migrations | — |

Pipeline naturel :
```
set (+ validation auto) → deploy → test → coverage
```

L'agent corrige au `set`, pas au `deploy`. Le deploy ne devrait jamais echouer si les `set` ont passe.
