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
