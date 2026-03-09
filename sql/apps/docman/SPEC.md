# Docman — Document Manager

## Vision

Un utilisateur a des documents eparpilles (fichiers locaux, pieces jointes email).
Docman les organise dans un systeme de classification relationnelle :
chaque document est rattache a une taxonomie (labels), a des acteurs metier (entites),
et a d'autres documents (relations).

L'agent IA est le moteur de classification. Il lit les documents, comprend leur contenu,
et les rattache au bon endroit dans le graphe. L'utilisateur pilote : il definit
sa taxonomie, ses types d'entites, et demande a l'agent de classer.

---

## 1. Le domaine : Classification

### Document

Un document est la fiche metier d'un fichier physique (docstore.file).
Il porte les metadonnees metier que le fichier seul ne contient pas :

- **doc_type** : type documentaire (facture, devis, contrat, courrier, releve, avenant...).
  Types libres, definis par l'usage. Distinct du sujet : une facture peut etre comptable
  ou juridique — le type dit *quoi*, la taxonomie dit *ou*.
- **document_date** : date metier du document (date de la facture, signature du contrat...).
  Distincte de `created_at` (date d'import). C'est la date de reference pour la recherche
  chronologique : "les factures de mars 2024" cherche sur `document_date`, pas sur l'import.
- **summary** : resume en texte libre, genere par l'agent apres lecture du contenu.
  Indexe en plein texte (tsvector) pour la recherche.

### Taxonomie

La taxonomie est un arbre de labels defini par l'utilisateur.

```
Comptabilite/
  Factures/
    Fournisseurs
    Clients
  Releves bancaires
  Declarations fiscales
Juridique/
  Contrats
  Avenants
Projets/
  Chantier Dupont
  Renovation Martin
```

Un label a un **kind** :
- `category` : noeud de l'arbre, hierarchique (parent/enfant)
- `tag` : transversal, plat (urgent, a-traiter, archive)

Chaque label peut porter des **aliases** (synonymes) : le label "Factures" peut avoir
les aliases ["invoice", "facture fournisseur", "bill"]. L'agent utilise les aliases
pour reconnaitre le terme canonique et eviter les doublons.

L'utilisateur cree sa taxonomie. L'agent l'utilise pour classer.
L'agent peut suggerer de nouveaux labels, l'utilisateur valide.

### Entites

Les entites sont les acteurs metier lies aux documents.
Les **kinds** sont libres et definis par l'utilisateur :

| Kind | Exemples |
|------|----------|
| client | Jean Dupont, SARL Martin |
| fournisseur | EDF, Leroy Merlin |
| projet | Renovation cuisine Dupont |
| banque | Credit Agricole |

Une entite porte des attributs specifiques en jsonb (email, tel, adresse...).
Une entite peut aussi porter des **aliases** : "EDF" = "Electricite de France" = "EDF ENR".
L'agent utilise les aliases pour reconcilier les variantes trouvees dans les documents.

La liaison document-entite porte un **role** : emetteur, destinataire, concerne, beneficiaire...

### Relations entre documents

Les documents forment un graphe :

```
Devis #42 --follows--> Facture #108 --paid_by--> Virement-2025-03.pdf
Contrat.pdf --supersedes--> Avenant-1.pdf
Email-EDF --attached_to--> Facture-EDF-mars.pdf
```

Types de relations : follows, paid_by, supersedes, attached_to, references...
Les types sont libres.

### Confiance

Chaque acte de classification porte une **confiance** (0.0 a 1.0) et une **origine**
(agent ou user). Cela permet :
- De prioriser la revue humaine sur les classifications incertaines
- De distinguer ce que l'agent a devine de ce que l'utilisateur a valide
- De mesurer la qualite de la classification dans le temps

---

## 2. Les actes

### Utilisateur

| Acte | Description |
|------|-------------|
| Definir la taxonomie | Creer/modifier/supprimer des labels (categories et tags) |
| Definir les types d'entites | Creer des kinds (client, fournisseur, projet...) |
| Creer des entites | Ajouter un client, un fournisseur... |
| Configurer les sources | Repertoire documents, compte email |
| Demander un import | "Synchronise mes documents" |
| Demander une classification | "Classe mes nouveaux documents" |
| Demander une recuperation email | "Recupere les factures EDF" |
| Chercher | "Trouve les factures fournisseur 2025" |
| Consulter | "Montre-moi ce document", "Quels labels existent ?" |
| Corriger | "Ce document n'est pas une facture, c'est un devis" |
| Revoir | "Montre-moi les documents classes avec faible confiance" |

### Agent

| Acte | Description |
|------|-------------|
| Consulter la taxonomie | Connaitre les labels existants (noms + aliases) avant de classer |
| Consulter les entites | Connaitre les clients/fournisseurs existants (noms + aliases) |
| Lire un document | Contenu + classification actuelle |
| Lister l'inbox | Documents a classer |
| Classer | Assigner labels, entites, relations, resume, type, date — avec confiance |
| Declasser | Retirer un label, une entite, une relation |
| Chercher | Trouver des documents par criteres (type, date, labels, entites, plein texte) |
| Importer | Scanner une source, enregistrer les nouveaux |
| Recuperer des emails | Chercher, telecharger, enregistrer |

---

## 3. Schema

```
docstore.file
  path PK, filename, extension, size_bytes, mime_type, content_hash, ...

docman.document
  id            uuid PK DEFAULT gen_random_uuid()
  file_path     text FK -> docstore.file(path) UNIQUE
  doc_type      text                        -- facture, devis, contrat, courrier...
  document_date date                        -- date metier (facture, signature...)
  source        text DEFAULT 'filesystem'   -- filesystem | email
  source_ref    text                        -- ref origine (message_id...)
  summary       text
  summary_tsv   tsvector GENERATED ALWAYS AS (to_tsvector('french', coalesce(summary, ''))) STORED
  classified_at timestamptz
  created_at    timestamptz DEFAULT now()

  INDEX idx_doc_summary_fts ON docman.document USING gin(summary_tsv)
  INDEX idx_doc_type ON docman.document(doc_type)
  INDEX idx_doc_date ON docman.document(document_date)

docman.label
  id          serial PK
  name        text NOT NULL
  kind        text NOT NULL DEFAULT 'tag'  -- category | tag
  parent_id   int FK -> docman.label(id)
  description text
  aliases     text[] DEFAULT '{}'          -- synonymes (ISO 25964 UF/USE)
  UNIQUE(name, kind, parent_id)

docman.entity
  id       serial PK
  kind     text NOT NULL
  name     text NOT NULL
  aliases  text[] DEFAULT '{}'             -- variantes du nom
  metadata jsonb DEFAULT '{}'
  UNIQUE(kind, name)

docman.document_label
  document_id  uuid FK -> docman.document(id) ON DELETE CASCADE
  label_id     int FK -> docman.label(id) ON DELETE CASCADE
  confidence   real DEFAULT 1.0            -- 0.0 a 1.0
  assigned_by  text DEFAULT 'agent'        -- agent | user
  assigned_at  timestamptz DEFAULT now()
  PK(document_id, label_id)

docman.document_entity
  document_id  uuid FK -> docman.document(id) ON DELETE CASCADE
  entity_id    int FK -> docman.entity(id) ON DELETE CASCADE
  role         text NOT NULL
  confidence   real DEFAULT 1.0
  assigned_by  text DEFAULT 'agent'
  assigned_at  timestamptz DEFAULT now()
  PK(document_id, entity_id, role)

docman.document_relation
  source_id  uuid FK -> docman.document(id) ON DELETE CASCADE
  target_id  uuid FK -> docman.document(id) ON DELETE CASCADE
  kind       text NOT NULL
  confidence real DEFAULT 1.0
  assigned_by text DEFAULT 'agent'
  assigned_at timestamptz DEFAULT now()
  PK(source_id, target_id, kind)
```

---

## 4. Primitives PL/pgSQL

### Documents
| Fonction | Role |
|----------|------|
| `docman.register(p_dir, p_source)` | Cree docman.document pour les nouveaux fichiers docstore |
| `docman.inbox(p_limit, p_max_confidence)` | Documents non classes, ou classes sous un seuil de confiance |
| `docman.peek(p_doc_id)` | Fiche document : metadata fichier + classification complete avec confiances |
| `docman.search(p_filters jsonb)` | Recherche multi-criteres : type, date, labels, entites, plein texte |

### Classification (atomique)
| Fonction | Role |
|----------|------|
| `docman.classify(p_doc_id, p_doc_type, p_document_date, p_summary, p_confidence)` | Poser type + date + resume + marquer classified_at |
| `docman.tag(p_doc_id, p_label, p_kind, p_parent, p_confidence)` | Assigner un label (cree a la volee si besoin, resout les aliases) |
| `docman.untag(p_doc_id, p_label_id)` | Retirer un label |
| `docman.link(p_doc_id, p_kind, p_name, p_role, p_confidence, p_metadata)` | Lier une entite (creee a la volee si besoin, resout les aliases) |
| `docman.unlink(p_doc_id, p_entity_id, p_role)` | Retirer un lien |
| `docman.relate(p_source_id, p_target_id, p_kind, p_confidence)` | Creer une relation |
| `docman.unrelate(p_source_id, p_target_id, p_kind)` | Retirer une relation |

### Consultation
| Fonction | Role |
|----------|------|
| `docman.labels(p_kind, p_parent_id)` | Lister les labels (arbre ou filtre par kind/parent), inclut aliases |
| `docman.entities(p_kind)` | Lister les entites (toutes ou par kind), inclut aliases |
| `docman.entity_kinds()` | Lister les kinds d'entites existants |
| `docman.relations(p_doc_id)` | Lister les relations d'un document |
| `docman.doc_types()` | Lister les types documentaires utilises |

---

## 5. Tools MCP

L'agent ne touche jamais au SQL. Chaque acte passe par une tool.

### Orchestrateurs
| Tool | Combine |
|------|---------|
| `doc_import` | fs_scan + docman.register() |
| `doc_fetch_mail` | gmail_* + fs_scan + docman.register() |
| `doc_peek` | docman.peek() + fs_peek() |

### Classification
| Tool | Appelle |
|------|---------|
| `doc_classify` | docman.classify() — type, date, resume en un acte |
| `doc_tag` | docman.tag() — avec confiance |
| `doc_untag` | docman.untag() |
| `doc_link` | docman.link() — avec confiance |
| `doc_unlink` | docman.unlink() |
| `doc_relate` | docman.relate() — avec confiance |
| `doc_unrelate` | docman.unrelate() |

### Consultation
| Tool | Appelle |
|------|---------|
| `doc_inbox` | docman.inbox() — filtre par confiance |
| `doc_search` | docman.search() — type, date, labels, entites, plein texte |
| `doc_labels` | docman.labels() — avec aliases |
| `doc_entities` | docman.entities() — avec aliases |
| `doc_entity_kinds` | docman.entity_kinds() |
| `doc_relations` | docman.relations() |
| `doc_doc_types` | docman.doc_types() |

---

## 6. Workflows

### Import
1. `doc_import` (path optionnel, sinon config DB)

### Classification
1. `doc_inbox` -> liste des documents a classer (ou a revoir si confiance faible)
2. `doc_labels` + `doc_entities` + `doc_doc_types` -> connaitre la taxonomie, les entites et types existants
3. `doc_peek(doc_id)` -> lire le document + sa classification actuelle
4. L'agent decide et compose un batch :
   - `doc_classify` (type, date, resume, confiance)
   - `doc_tag` (labels, confiance)
   - `doc_link` (entites, confiance)
   - `doc_relate` (relations, confiance)
5. Document suivant

### Recuperation email
1. `doc_fetch_mail(query)` -> cherche, telecharge, enregistre
2. -> Classification

### Recherche
1. `doc_search(filtres)` -> par type, date metier, labels, entites, plein texte, source...

### Correction
1. `doc_peek(doc_id)` -> voir la classification actuelle (avec confiances)
2. `doc_untag`, `doc_unlink`, `doc_unrelate` -> retirer ce qui est faux
3. `doc_classify`, `doc_tag`, `doc_link`, `doc_relate` -> ajouter/corriger (assigned_by = user, confiance = 1.0)

### Revue
1. `doc_inbox(max_confidence: 0.7)` -> documents classes avec faible confiance
2. `doc_peek(doc_id)` -> voir ce que l'agent a fait
3. Correction ou validation (re-tag/re-link avec assigned_by = user)

### Consultation taxonomie
1. `doc_labels` -> arbre des categories et tags, avec aliases
2. `doc_entities` / `doc_entity_kinds` -> entites et types existants
3. `doc_doc_types` -> types documentaires utilises
