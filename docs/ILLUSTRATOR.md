# ILLUSTRATOR.md — Integration MCP Illustrator

> Moteur de rendu documentaire pour la plateforme pgView.
> MCP Illustrator est le composant de composition et d'export PDF pour tous les documents : devis, factures, brochures produits, communication.

## Vision

Deux mondes, un seul moteur de rendu :

```
+------------------------------------------------------------------+
|  pgView (PostgreSQL)           |  MCP Illustrator                |
|  ============================  |  ============================== |
|  Affichage web interactif      |  Documents imprimables (PDF)    |
|  get_devis() -> HTML browser   |  Composition A4 -> PDF 300 DPI  |
|  Navigation, CRUD, workflow    |  Brochures, catalogues, com'    |
|  Temps reel, Alpine.js shell   |  Export pro, bleed, crop marks  |
+------------------------------------------------------------------+
                  |                              |
                  +--------- bridge -------------+
                  |                              |
          Donnees metier (PL/pgSQL)     Layout (Illustrator tools)
```

pgView genere le HTML pour le navigateur. Illustrator compose les documents pour l'impression et l'export. Les donnees viennent du meme endroit : PostgreSQL.

## Pourquoi Illustrator (pas un moteur HTML-to-PDF)

Les moteurs HTML-to-PDF (Gotenberg, WeasyPrint, Puppeteer) convertissent du HTML en PDF. Ca marche, mais :

| | HTML-to-PDF | Illustrator |
|---|------------|-------------|
| Controle layout | CSS @page, limites navigateur | Millimetrique, pixel-perfect |
| Typographie | Approximative (navigateur) | Precise (opentype.js, mesure glyphes) |
| Images | Contraintes CSS | Crop, zoom, filtres, ombres |
| Bleed / crop marks | Hack ou impossible | Natif, configurable |
| Brochures / com' | Hors scope | Use case principal |
| Template reutilisable | HTML + CSS a maintenir | Document clonable |
| UI de design | Aucune | Editeur web interactif |
| Clients potentiels | Aucun (c'est de l'infra) | Produit vendable separement |

L'argument decisif : Illustrator sert **aussi** pour la communication (brochures, flyers, catalogues produit). Un moteur HTML-to-PDF ne fait que de la conversion — Illustrator est un outil de creation.

## Architecture d'integration

### Composants

```
+---------------------------+        +---------------------------+
|  plpgsql-workbench        |        |  mcp-illustrator          |
|  (MCP server :3100)       |        |  (MCP server, stdio)      |
|                           |        |                           |
|  pg_query / pg_get        |        |  doc_new / doc_duplicate  |
|  -> donnees metier        |        |  batch_add / batch_update |
|                           |        |  export_pdf / snapshot    |
|  quote.devis_data(id)     |        |                           |
|  quote.facture_data(id)   |        |  Templates = documents    |
|  crm.client_data(id)      |        |  stockes dans SQLite      |
+---------------------------+        +---------------------------+
              |                                    |
              +------------- bridge ---------------+
              |                                    |
     +------------------+                          |
     |  Orchestrateur   |  (agent Claude, MCP tool, ou script)
     |  1. Query data   |
     |  2. Clone template|
     |  3. Fill data     |
     |  4. Export PDF    |
     +------------------+
```

### Flux de generation

```
1. QUERY     pg_query("SELECT quote.devis_data(42)")
             -> { numero, date, client, lignes[], totaux, mentions[] }

2. CLONE     doc_duplicate("tpl-devis-standard")
             -> nouveau document "DEV-2026-042"

3. FILL      batch_update([
               { name: "numero",     text: "DEV-2026-042" },
               { name: "date",       text: "13 mars 2026" },
               { name: "client-nom", text: "Dupont SARL" },
               ...
             ])
             + generation dynamique du tableau de lignes

4. EXPORT    export_pdf({ format: "A4", home_print: true })
             -> PDF binaire

5. CLEANUP   doc_delete("DEV-2026-042")
             (ou archivage si besoin de re-generation)
```

## Templates

### Principe : template = document

Pas de DSL, pas de Jinja, pas de moteur de substitution. Un template est un **document Illustrator standard** avec des elements nommes :

```
tpl-devis-standard (A4 portrait)
├── logo              image    (x:15, y:15, w:40, h:20)
├── entreprise-nom    text     (x:15, y:40, "ACME SARL")
├── entreprise-addr   text     (x:15, y:48, "12 rue des Lilas...")
├── entreprise-siret  text     (x:15, y:62, "SIRET: 123 456 789 00001")
├── entreprise-tva    text     (x:15, y:67, "TVA: FR12345678900")
├── client-nom        text     (x:120, y:40, "[client]")
├── client-addr       text     (x:120, y:48, "[adresse]")
├── titre             text     (x:15, y:90, "DEVIS DEV-XXXX-XXX")
├── date              text     (x:160, y:90, "[date]")
├── validite          text     (x:160, y:96, "Valide 30 jours")
├── table-header      group    (y:110)
│   ├── col-desc      text     "Description"
│   ├── col-qte       text     "Qte"
│   ├── col-unite     text     "Unite"
│   ├── col-pu        text     "P.U. HT"
│   ├── col-tva       text     "TVA"
│   └── col-total     text     "Total HT"
├── table-lines       group    (y:118, genere dynamiquement)
├── total-ht          text     (x:160, y: calc, "Total HT: 1 234,00")
├── total-tva         text     (x:160, y: calc, "TVA 20%:   246,80")
├── total-ttc         text     (x:160, y: calc, "Total TTC: 1 480,80")
├── mentions          group    (y: bottom - 40)
│   ├── mention-1     text     "Delai de paiement: 30 jours..."
│   ├── mention-2     text     "Penalites de retard: 10%..."
│   └── mention-3     text     "Indemnite forfaitaire: 40 EUR"
├── watermark         text     (center, rotate:-45, opacity:0.08, "BROUILLON")
└── footer            group    (y: bottom - 10)
    ├── page-num      text     "Page 1/1"
    └── generation    text     "Genere le 13/03/2026"
```

### Convention de nommage

Les elements portent des noms semantiques que l'orchestrateur connait :

| Prefixe | Contenu | Source |
|---------|---------|--------|
| `entreprise-*` | Coordonnees emetteur | `workbench.config('quote', ...)` |
| `client-*` | Coordonnees destinataire | `crm.client` |
| `titre`, `numero`, `date` | En-tete document | `quote.devis` / `quote.facture` |
| `table-header`, `table-lines` | Tableau des lignes | `quote.ligne` |
| `total-*` | Bloc totaux | Calcul `_total_ht/tva/ttc` |
| `mention-*` | Mentions legales | `quote.mention` |
| `watermark` | Filigrane conditionnel | Statut (BROUILLON, PAYE, ANNULE) |
| `footer` | Pied de page | Metadata generation |

### Types de templates

| Template | Format | Usage |
|----------|--------|-------|
| `tpl-devis-standard` | A4 portrait | Devis classique |
| `tpl-facture-standard` | A4 portrait | Facture |
| `tpl-bon-livraison` | A4 portrait | Bon de livraison |
| `tpl-avoir` | A4 portrait | Avoir / credit |
| `tpl-relance` | A4 portrait | Lettre de relance |
| `tpl-brochure-produit` | A4 paysage | Fiche produit catalogue |
| `tpl-catalogue-*` | A3/A4 | Catalogue multi-pages |

### Personnalisation par tenant

Les templates sont des documents Illustrator. Personnaliser = modifier le document :

1. **Branding** — Remplacer le logo, les couleurs, les polices
2. **Layout** — Deplacer les blocs, redimensionner
3. **Contenu fixe** — Modifier les mentions, ajouter un slogan
4. **Nouveau template** — Dupliquer + modifier via l'UI web (localhost:3333)

Pas de systeme de "theme" abstrait. Le template EST le design final — l'utilisateur ou l'agent le modifie directement.

## Donnees metier

### Fonctions d'extraction

Chaque module expose une fonction `*_data()` qui retourne un JSONB structure, pret pour le remplissage :

```sql
-- quote.devis_data(p_id int) RETURNS jsonb
{
  "numero": "DEV-2026-042",
  "date": "2026-03-13",
  "validite": "2026-04-12",
  "statut": "brouillon",

  "entreprise": {
    "nom": "ACME SARL",
    "adresse": "12 rue des Lilas, 39000 Lons-le-Saunier",
    "siret": "123 456 789 00001",
    "tva_intra": "FR12345678900",
    "telephone": "03 84 XX XX XX",
    "email": "contact@acme.fr"
  },

  "client": {
    "nom": "Dupont SARL",
    "adresse": "5 avenue de la Gare, 25000 Besancon",
    "siret": "987 654 321 00001"
  },

  "lignes": [
    {
      "description": "Conduit inox double paroi DN150",
      "quantite": 6,
      "unite": "ml",
      "prix_unitaire": 89.50,
      "tva_rate": 20,
      "total_ht": 537.00
    },
    ...
  ],

  "totaux": {
    "total_ht": 1234.00,
    "total_tva": 246.80,
    "total_ttc": 1480.80,
    "tva_detail": [
      { "taux": 20, "base": 1234.00, "montant": 246.80 }
    ]
  },

  "mentions": [
    { "label": "Delai de paiement", "texte": "30 jours a compter de..." },
    { "label": "Penalites de retard", "texte": "10% annuel..." },
    { "label": "Indemnite forfaitaire", "texte": "40 EUR..." }
  ]
}
```

### Coordonnees entreprise

Stockees dans `workbench.config` (pas dans le template) :

```sql
SELECT workbench.config('quote', 'entreprise_nom');
SELECT workbench.config('quote', 'entreprise_siret');
SELECT workbench.config('quote', 'entreprise_logo_path');
-- etc.
```

Le template contient des placeholders. L'orchestrateur les remplace par les valeurs config au moment de la generation.

## Generation dynamique du tableau

Le tableau de lignes est le seul element qui varie en taille. L'orchestrateur doit :

1. **Supprimer** le groupe `table-lines` du template (placeholder)
2. **Calculer** la position Y de depart (sous `table-header`)
3. **Ajouter** une ligne par element de `lignes[]` via `batch_add`
4. **Ajuster** les positions des blocs suivants (`total-*`, `mentions`, `footer`)

```
Pour chaque ligne:
  add_text(name: "line-N-desc",  x: 15,  y: Y, text: ligne.description, fontSize: 8)
  add_text(name: "line-N-qte",  x: 120, y: Y, text: ligne.quantite,    fontSize: 8)
  add_text(name: "line-N-pu",   x: 145, y: Y, text: ligne.prix_unitaire, fontSize: 8)
  add_text(name: "line-N-total",x: 175, y: Y, text: ligne.total_ht,    fontSize: 8)
  Y += line_height (environ 5mm)
```

### Multi-page

Si le tableau depasse la zone imprimable :

1. Detecter le depassement (Y > page_height - footer_height)
2. Couper le tableau, ajouter "Suite page suivante"
3. Creer un second document (page 2) avec le reste des lignes
4. Generer les PDFs separement, concatener (ou gerer via un futur `multi_page` dans Illustrator)

**Evolution Illustrator necessaire** : support multi-page natif (aujourd'hui 1 doc = 1 page).

## Watermarks et statuts

| Statut | Watermark | Opacite | Rotation |
|--------|-----------|---------|----------|
| `brouillon` | BROUILLON | 0.08 | -45 deg |
| `envoye` / `envoyee` | _(aucun)_ | — | — |
| `accepte` | ACCEPTE | 0.05 | -45 deg |
| `refuse` | REFUSE | 0.08 | -45 deg |
| `payee` | PAYE | 0.05 | -45 deg |
| `annule` | ANNULE | 0.10 | -45 deg |

L'orchestrateur met a jour l'element `watermark` (texte, opacite) ou le supprime selon le statut.

## Use cases

### 1. Documents commerciaux (automatique)

```
Utilisateur clique "Telecharger PDF" sur un devis
  -> post_devis_pdf(id)
  -> orchestrateur query data + clone template + fill + export
  -> PDF retourne au navigateur
```

Entierement automatise. L'utilisateur ne voit jamais Illustrator.

### 2. Brochure produit (semi-automatique)

```
Agent recoit : "Fais-moi une fiche produit pour le conduit DN150"
  -> Query donnees catalogue (stock, prix, specs)
  -> doc_duplicate("tpl-brochure-produit")
  -> Compose : photo produit, specs techniques, prix, argumentaire
  -> Ajuste le layout (positionnement, couleurs)
  -> export_pdf -> PDF
```

L'agent utilise les MCP tools directement. L'utilisateur peut ensuite affiner via l'UI.

### 3. Communication (creatif)

```
Agent recoit : "Cree une affiche pour les portes ouvertes du 15 avril"
  -> doc_new format A3 portrait
  -> Compose librement (titre, photo, programme, logo, QR code)
  -> snapshot -> preview PNG
  -> Iterations avec l'utilisateur
  -> export_pdf -> PDF pro pour imprimeur
```

Aucun template pre-defini. Composition libre pilotee par l'agent.

## Factur-X (e-invoicing 2026-2027)

La facturation electronique impose le format **Factur-X** : un PDF/A-3 avec XML CII embarque.

### Pipeline

```
1. export_pdf(facture)           -> PDF standard
2. quote.facture_xml_cii(id)     -> XML CII (genere par PL/pgSQL via xmlelement/xmlforest)
3. facturx_embed(pdf, xml)       -> PDF/A-3 avec XML attache
```

L'etape 3 necessite un outil d'embedding (Python `factur-x` lib par Akretion, ou Ghostscript). Peut etre un service Docker sidecar minimaliste.

### XML CII

PL/pgSQL genere le XML nativement :

```sql
SELECT xmlelement(
  name "rsm:CrossIndustryInvoice",
  xmlattributes('urn:un:unece:uncefact:data:standard:...' AS "xmlns:rsm"),
  xmlelement(name "rsm:ExchangedDocumentContext", ...),
  xmlelement(name "rsm:ExchangedDocument",
    xmlelement(name "ram:ID", f.numero),
    xmlelement(name "ram:TypeCode", '380'),
    xmlelement(name "ram:IssueDateTime", ...)
  ),
  ...
)
FROM quote.facture f WHERE f.id = p_id;
```

Zero dependance externe pour la generation XML. Seul l'embedding dans le PDF necessite un outil tiers.

## Evolutions Illustrator necessaires

| Evolution | Priorite | Description |
|-----------|----------|-------------|
| **Multi-page** | Haute | Support natif de documents multi-pages (factures longues, catalogues) |
| **Tableaux** | Haute | Element `table` natif avec colonnes, lignes, auto-layout |
| **Variables** | Moyenne | Systeme `{{nom}}` optionnel pour pre-remplissage sans batch_update |
| **QR Code** | Moyenne | Generation QR natif (paiement, lien web, Factur-X) |
| **PDF/A** | Moyenne | Export PDF/A-3 natif (pre-requis Factur-X sans outil tiers) |
| **Fusion PDF** | Basse | Concatenation multi-pages en un seul fichier |
| **Styles** | Basse | Presets de styles reutilisables (police + taille + couleur = "body") |

## Positionnement commercial

```
+-----------------------------------------------+
|  Produit                | Cible               |
|======================== |=====================|
|  ERP pgView             | TPE/PME (gestion)   |
|  + Illustrator integre  | Documents pro       |
|  Illustrator standalone | Agences, artisans   |
|                         | (com', brochures)   |
+-----------------------------------------------+
```

Illustrator a une double vie :

1. **Composant integre** — Le moteur PDF de l'ERP. L'utilisateur final ne le voit pas, il clique "Telecharger PDF" et ca marche.
2. **Produit autonome** — Un outil de creation documentaire pilote par IA. Les clients l'achetent pour faire leurs brochures, flyers, catalogues.

Cette dualite est un avantage strategique : le meme code sert deux marches.
