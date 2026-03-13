# expense — Notes de Frais

Module notes de frais : déplacements, achats, repas, remboursements.

**Dépend de :** pgv (framework UI)

**Lié à :** ledger (écriture comptable au remboursement), project (frais liés à un chantier)

**Schemas :** `expense` (public), `expense_ut` (tests), `expense_qa` (seed data)

## Modèle de données

- `expense.categorie` — catégories de frais avec code comptable (déplacement, repas, outillage...)
- `expense.note` — note de frais = regroupement de lignes avec statut workflow (brouillon → soumise → validée → remboursée)
- `expense.ligne` — ligne de dépense : date, catégorie, montant HT/TVA/TTC, km si déplacement, justificatif

## Pages attendues

- `get_index()` — dashboard : stats (total en cours, nb notes, montant moyen), liste notes récentes
- `get_note(p_id)` — détail note : infos, lignes, totaux, boutons workflow (soumettre/valider/rembourser)
- `get_note_form(p_params jsonb)` — formulaire création/édition note
- `get_notes(p_params jsonb)` — liste filtrée par statut, auteur, période
- `post_note_creer(p_params jsonb)` — créer une note
- `post_ligne_ajouter(p_params jsonb)` — ajouter une ligne à une note
- `post_note_soumettre(p_params jsonb)` — passer brouillon → soumise
- `post_note_valider(p_params jsonb)` — passer soumise → validée
- `post_note_rembourser(p_params jsonb)` — passer validée → remboursée (+ écriture ledger si dispo)

## Convention routeur

**IMPORTANT :** `pgv.route()` supporte max 1 argument par fonction. Utiliser `jsonb` pour les fonctions avec filtres/paramètres multiples.

## Intégration cross-module

- **ledger** : au remboursement, créer écriture comptable via EXECUTE dynamique si ledger existe
- **project** : optionnel — lier une note à un chantier (colonne nullable chantier_id)

## Workflow dev (STRICT)

1. DDL → Write dans `build/expense.ddl.sql` → `pg_schema` pour appliquer
2. Fonctions → `pg_func_set` pour créer/modifier + `pg_test` pour valider
3. Exporter → `pg_pack` (→ `build/expense.func.sql`) + `pg_func_save` (→ `src/`)
4. `pg_query` → SELECT/DML uniquement, JAMAIS de DDL ou CREATE FUNCTION

## Conventions pgView

- Tables via `<md>` blocks, JAMAIS `<table>` HTML
- CSS classes `pgv-*`, JAMAIS `style="..."`
- Primitives : `pgv.stat()`, `pgv.badge()`, `pgv.card()`, `pgv.grid()`, `pgv.empty()`, `pgv.action()`
- POST retourne raw HTML (toast/redirect), jamais wrappé dans `page()`

## Communication inter-modules

- `pg_msg_inbox module:expense` → lire les messages entrants
- `pg_msg` → envoyer un message à un autre module
- **feature_request / bug_report → TOUJOURS via issue_report** : ne jamais envoyer de feature_request ou bug_report directement à un autre module. Créer une issue : `INSERT INTO workbench.issue_report(issue_type, module, description) VALUES ('enhancement|bug', '<module_cible>', '<description>')`. Le lead sera notifié et décidera du dispatch.
- Chaque module est autonome — ne jamais modifier les fonctions d'un autre module

## i18n

Le framework utilise `pgv.t(key)` pour l'internationalisation. Chaque module doit :
1. Créer `expense.i18n_seed()` — INSERT INTO pgv.i18n(lang, key, value) les traductions FR
2. Clés namespaced : `expense.nav_xxx`, `expense.title_xxx`, `expense.btn_xxx`, etc.
3. Utiliser `pgv.t('expense.xxx')` dans nav_items(), brand(), et toutes les fonctions get_*/post_*
4. `ON CONFLICT DO NOTHING` dans le seed

## QA Seed Data

Le schema `expense_qa` contient uniquement `seed()` et `clean()` — PAS de pages.
- `expense_qa.seed()` — INSERT données démo réalistes
- `expense_qa.clean()` — DELETE dans l'ordre inverse des FK
- `ON CONFLICT DO NOTHING`, penser multi-tenant (`current_setting('app.tenant_id', true)`)

## Workflow agent

1. Au démarrage ou quand on te dit "go" : **toujours lire `pg_msg_inbox module:expense`**
2. Traiter les messages par priorité (HIGH d'abord)
3. Ne pas résoudre un message tant que la tâche n'est pas vérifiée
4. Après chaque tâche : `pg_pack schemas: expense,expense_ut,expense_qa` (les 3 schemas)
5. Puis `pg_func_save target: plpgsql://expense` + `plpgsql://expense_ut` + `plpgsql://expense_qa`


## Documentation intégrée

Le workbench embarque de la documentation accessible via `pg_doc` :
- `pg_doc topic:testing` — Guide pgTAP : conventions test_*(), assertions, patterns
- `pg_doc topic:data-convention` — Convention data_*() : cursor pagination, FTS, pgv.table()
- `pg_doc topic:coverage` — Guide couverture de code

## Gotchas

- **tenant_id** : toujours `PERFORM set_config('app.tenant_id', 'test', true)` au début de chaque test
- **pg_test** : découvre les fonctions `test_*()` dans le schema `_ut`

- **Tu es l'agent expense, PAS le lead.** Ne jamais utiliser `ws_health` pour trouver tes tâches — il montre TOUTES les tasks du workspace. Utiliser uniquement `pg_msg_inbox module:expense` pour lire TES messages. Ne traiter que les messages adressés à `expense`.
- (a completer au fil du developpement)
