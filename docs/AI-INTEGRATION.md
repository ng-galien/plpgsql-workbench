# AI Integration — pgView + LLM

## Pourquoi pgView est AI-native

L'architecture pgView a un avantage structurel pour l'intégration AI : **tout est du SQL**.

```
App classique (React/Node)         pgView (PostgreSQL only)
──────────────────────────         ─────────────────────────
L'IA doit comprendre :             L'IA doit comprendre :
  - React components                 - Des tables SQL
  - API REST (10+ endpoints)         - Des fonctions SQL
  - State management                 - C'est tout.
  - Auth middleware
  - ORM (Prisma/Sequelize)
  - 500+ packages npm

L'IA génère :                      L'IA génère :
  - JS + API calls + state           - Du SQL
  - Risque d'erreur : élevé          - Risque d'erreur : faible
  - Difficilement vérifiable         - Testable (EXPLAIN, pgTAP)
```

Un LLM sait parfaitement écrire du SQL — c'est dans ses données d'entraînement depuis le début. Lui demander de naviguer une app React avec 47 fichiers de config, c'est 10x plus complexe.

---

## Les 3 niveaux d'intégration

### Niveau 1 — Claude + MCP (déjà fonctionnel, 0 dev)

Le MCP server `plpgsql-workbench` qu'on a construit EST l'interface AI ↔ ERP.

```
Artisan utilise Claude Desktop / Claude Code
  ↕ MCP (plpgsql-workbench, 11 outils)
  ↕ PostgreSQL (données métier)
```

#### Exemples concrets

**Question analytique :**
```
Artisan : "Combien j'ai facturé ce mois-ci ?"

Claude → MCP query:
  SELECT sum(total) FROM shop.orders
  WHERE created_at >= date_trunc('month', now())
  AND status != 'cancelled'

→ "12 450,00 € ce mois-ci (23 commandes confirmées)"
```

**Recherche complexe :**
```
Artisan : "Quels clients n'ont pas commandé depuis 6 mois ?"

Claude → MCP query:
  SELECT c.name, c.email, max(o.created_at) AS last_order
  FROM shop.customers c
  LEFT JOIN shop.orders o ON o.customer_id = c.id AND o.status != 'cancelled'
  GROUP BY c.id HAVING max(o.created_at) < now() - interval '6 months'
  ORDER BY last_order

→ Tableau des clients inactifs avec date de dernière commande
```

**Action métier :**
```
Artisan : "Crée un devis pour Dupont, 2 fumoirs petit modèle"

Claude → MCP query:
  SELECT shop.place_order(
    (SELECT id FROM shop.customers WHERE name ILIKE '%dupont%'),
    '[{"product_id": 1, "quantity": 2}]'::jsonb
  )

→ "Commande #47 créée pour Dupont — 2x Fumoir Petit = 2 598€"
```

**Développement :**
```
Artisan : "Ajoute une colonne téléphone aux clients"

Claude → MCP set:
  ALTER TABLE shop.customers ADD COLUMN phone text;

Claude → MCP edit (pgv_customer):
  + format('<dt>Téléphone</dt><dd>%s</dd>', shop.esc(v_cust.phone))

→ Feature déployée en 30 secondes, visible au prochain F5.
```

#### Outils MCP disponibles

| Outil | Usage AI |
|-------|----------|
| `query` | Lire des données, exécuter des actions métier |
| `get` | Explorer le schéma (tables, fonctions, colonnes) |
| `search` | Trouver une fonction ou table par nom/contenu |
| `set` | Créer/modifier une fonction (ajouter une feature) |
| `edit` | Patcher une fonction existante |
| `test` | Vérifier que les tests passent après un changement |
| `explain` | Analyser la performance d'une requête |
| `coverage` | Vérifier la couverture de tests |
| `doc` | Visualiser les dépendances entre fonctions |
| `dump` | Exporter les fonctions pour versioning |
| `apply` | Appliquer un fichier SQL |

**Coût de cette intégration : 0€, 0 lignes de code. C'est déjà là.**

---

### Niveau 2 — Chat dans pgView (1 jour de dev)

Un widget chat intégré dans l'application web pgView.

#### Architecture

```
┌────────────────────────────────────────────────────┐
│  pgView (navigateur de l'artisan)                  │
│                                                    │
│  ┌──────────────────────────────────────────────┐  │
│  │  💬 Combien de commandes cette semaine ?      │  │
│  │                                              │  │
│  │  > 8 commandes, 3 240€ de CA.                │  │
│  │    Top produit : Fumoir Grand (4 vendus)     │  │
│  │                                              │  │
│  │  [________________________________] [Envoyer]│  │
│  └──────────────────────────────────────────────┘  │
└──────────┬─────────────────────────────────────────┘
           │
           │ POST /functions/v1/chat { message, tenant_id }
           ▼
┌──────────────────────────┐
│  Supabase Edge Function  │
│  (Deno, ~40 lignes)      │
│                          │
│  1. Charge le schéma DB  │
│  2. Appelle Claude API   │
│  3. Claude génère du SQL │
│  4. Exécute le SQL       │
│  5. Retourne la réponse  │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  PostgreSQL              │
│  (même DB, même données) │
└──────────────────────────┘
```

#### Edge Function

```typescript
// supabase/functions/chat/index.ts
import Anthropic from "@anthropic-ai/sdk";
import { createClient } from "@supabase/supabase-js";

const anthropic = new Anthropic();
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const SCHEMA = `
Tables disponibles (schema shop) :
- customers (id serial, name text, email text, created_at timestamptz)
- products (id serial, name text, price numeric, stock integer)
- orders (id serial, customer_id int, status text, subtotal numeric,
         discount_amount numeric, total numeric, discount_code text, created_at timestamptz)
- order_items (id serial, order_id int, product_id int, quantity int,
              unit_price numeric, subtotal numeric)
- discounts (code text PK, kind text, value numeric, min_order numeric, active boolean)

Fonctions disponibles :
- place_order(customer_id int, items jsonb, discount_code text) → int
- cancel_order(order_id int) → boolean
- customer_tier(customer_id int) → text (bronze/silver/gold/platinum)
- apply_discount(code text, subtotal numeric, item_count int) → numeric

Status possibles pour orders : pending, confirmed, shipped, cancelled
`;

Deno.serve(async (req) => {
  const { message, tenant_id } = await req.json();

  // 1. Demander à Claude de générer du SQL
  const response = await anthropic.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 1024,
    system: `Tu es l'assistant de gestion d'un artisan.
Voici sa base de données :
${SCHEMA}

Règles :
- Génère UNIQUEMENT du SQL SELECT pour les questions (lecture seule)
- Pour les actions (créer, modifier, annuler), utilise les fonctions métier
- Ajoute toujours un filtre tenant : WHERE tenant_id = ${tenant_id}
- Réponds en français, concis
- Formate les montants en euros
- Retourne le SQL entre balises <sql>...</sql>
- Retourne ta réponse en langage naturel après le résultat`,
    messages: [{ role: "user", content: message }],
  });

  // 2. Extraire le SQL
  const text = response.content[0].type === "text" ? response.content[0].text : "";
  const sqlMatch = text.match(/<sql>([\s\S]*?)<\/sql>/);

  if (!sqlMatch) {
    return Response.json({ answer: text });
  }

  // 3. Exécuter le SQL (lecture seule, avec timeout)
  const { data, error } = await supabase.rpc("run_query", {
    sql: sqlMatch[1],
    p_tenant_id: tenant_id,
  });

  if (error) {
    return Response.json({ answer: `Erreur : ${error.message}` });
  }

  // 4. Demander à Claude de formater la réponse
  const formatResponse = await anthropic.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 512,
    system: "Formate ce résultat SQL en réponse concise en français pour un artisan.",
    messages: [
      { role: "user", content: `Question: ${message}\nRésultat SQL: ${JSON.stringify(data)}` },
    ],
  });

  const answer = formatResponse.content[0].type === "text"
    ? formatResponse.content[0].text
    : "Pas de réponse";

  return Response.json({ answer });
});
```

#### Fonction SQL sécurisée (côté PostgreSQL)

```sql
-- Exécution SQL sandboxée pour le chat AI
CREATE FUNCTION shop.run_query(sql text, p_tenant_id integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- Bloquer les écritures
  IF sql ~* '^\s*(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|TRUNCATE)' THEN
    RAISE EXCEPTION 'read-only queries only';
  END IF;

  -- Injecter le tenant_id dans le search_path / session
  PERFORM set_config('app.tenant_id', p_tenant_id::text, true);

  -- Exécuter avec timeout
  SET LOCAL statement_timeout = '5s';
  EXECUTE format('SELECT jsonb_agg(row_to_json(t)) FROM (%s) t', sql)
    INTO v_result;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;
```

#### Widget chat pgView

```sql
-- Ajouter à pgv_dashboard() ou comme composant global
CREATE FUNCTION shop.pgv_chat()
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT '
<div style="position:fixed;bottom:20px;right:20px;z-index:999">
  <div id="chat-box" style="display:none;width:400px;background:var(--pico-card-background-color);
       border:1px solid var(--pico-muted-border-color);border-radius:12px;padding:1rem;
       box-shadow:0 4px 24px rgba(0,0,0,0.15);margin-bottom:0.5rem">
    <div id="chat-messages" style="height:300px;overflow-y:auto;margin-bottom:1rem"></div>
    <form id="chat-form" style="display:flex;gap:0.5rem">
      <input type="text" id="chat-input" placeholder="Pose une question..."
             style="margin-bottom:0;flex:1">
      <button type="submit" style="margin-bottom:0;width:auto">Envoyer</button>
    </form>
  </div>
  <button onclick="document.getElementById(''chat-box'').style.display=
    document.getElementById(''chat-box'').style.display===''none''?''block'':''none''"
    style="border-radius:50%;width:56px;height:56px;font-size:1.5rem;cursor:pointer">
    💬
  </button>
</div>

<script>
document.getElementById("chat-form").addEventListener("submit", function(e) {
  e.preventDefault();
  var input = document.getElementById("chat-input");
  var msg = input.value.trim();
  if (!msg) return;
  var msgs = document.getElementById("chat-messages");
  msgs.innerHTML += "<p><strong>Vous :</strong> " + msg + "</p>";
  input.value = "";
  msgs.innerHTML += "<p aria-busy=\"true\">...</p>";
  fetch("/functions/v1/chat", {
    method: "POST",
    headers: { "Content-Type": "application/json",
               "Authorization": "Bearer " + window.SUPABASE_KEY },
    body: JSON.stringify({ message: msg, tenant_id: window.TENANT_ID })
  })
  .then(function(r) { return r.json(); })
  .then(function(data) {
    msgs.lastChild.remove();
    msgs.innerHTML += "<p><strong>Assistant :</strong> " + data.answer + "</p>";
    msgs.scrollTop = msgs.scrollHeight;
  });
});
</script>';
$$;
```

#### Coût par question

```
Claude Sonnet :
  - Input  : ~500 tokens (schema + question)     = $0.0015
  - Output : ~200 tokens (SQL + réponse)          = $0.0010
  - Format : ~300 tokens (2e appel)               = $0.0012
  Total : ~$0.004 par question (~0.004€)

  100 questions/mois = 0.40€/client/mois
  1000 questions/mois = 4€/client/mois
```

---

### Niveau 3 — Agent autonome (v3)

L'artisan n'ouvre plus l'app. Il interagit par WhatsApp, SMS ou email.

#### Architecture

```
WhatsApp / SMS / Email
       │
       ▼
Twilio / Resend webhook
       │
       ▼
Supabase Edge Function
       │
       ├── Claude API (comprendre l'intention)
       │       │
       │       ▼
       ├── PostgreSQL (lire/écrire via fonctions métier)
       │       │
       │       ▼
       ├── pg_net (actions externes : emails, notifications)
       │
       ▼
Réponse WhatsApp / SMS / Email
```

#### Cas d'usage agent

| Message artisan | Action agent |
|----------------|-------------|
| "Relance les clients inactifs" | Query clients inactifs → génère emails personnalisés → envoie via Resend → log dans la DB |
| "Combien de stock reste pour le fumoir grand ?" | Query → "Il reste 12 unités" |
| "Crée un devis pour Mme Martin, 1 fumoir petit + installation" | place_order() → PDF → envoi par email au client |
| "Annule la commande 34" | cancel_order(34) → "Commande annulée, stock restauré" |
| "Envoie la facture du mois à mon comptable" | Query commandes du mois → génère export → email |
| "Quel est mon CA ce trimestre vs le précédent ?" | 2 queries → comparaison → graphique texte |

#### Guardrails

```sql
-- L'agent ne peut utiliser QUE les fonctions métier exposées
-- Pas de SQL brut en écriture
-- Chaque action est loggée (supa_audit)
-- Confirmation requise pour les actions destructives (annulation, suppression)

-- Fonction d'exécution d'action pour l'agent
CREATE FUNCTION shop.agent_action(
  p_tenant_id integer,
  p_action text,        -- 'place_order', 'cancel_order', ...
  p_params jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM set_config('app.tenant_id', p_tenant_id::text, true);

  CASE p_action
    WHEN 'place_order' THEN
      RETURN jsonb_build_object('order_id',
        shop.place_order(
          (p_params->>'customer_id')::int,
          p_params->'items',
          p_params->>'discount_code'
        ));

    WHEN 'cancel_order' THEN
      RETURN jsonb_build_object('cancelled',
        shop.cancel_order((p_params->>'order_id')::int));

    ELSE
      RAISE EXCEPTION 'unknown action: %', p_action;
  END CASE;
END;
$$;
```

---

## Modèle "pgView pour voir, AI pour agir"

```
┌──────────────────────────────────────────────────────┐
│                    L'artisan                          │
│                                                      │
│    "Je veux voir"              "Je veux faire"       │
│         │                           │                │
│         ▼                           ▼                │
│    ┌──────────┐              ┌────────────┐          │
│    │  pgView  │              │  AI Chat   │          │
│    │ Dashboard│              │ (NL → SQL) │          │
│    │ Listes   │              │            │          │
│    │ Fiches   │              │ Questions  │          │
│    │ Graphes  │              │ Actions    │          │
│    └────┬─────┘              │ Rapports   │          │
│         │                    └─────┬──────┘          │
│         │                          │                 │
│         ▼                          ▼                 │
│    ┌──────────────────────────────────────┐          │
│    │         PostgreSQL                   │          │
│    │  Tables + Fonctions + RLS            │          │
│    │  (source unique de vérité)           │          │
│    └──────────────────────────────────────┘          │
└──────────────────────────────────────────────────────┘
```

Les deux interfaces (pgView et AI) tapent dans la même DB, les mêmes fonctions, les mêmes règles métier. Pas de duplication de logique.

---

## Pricing avec AI

| Offre | Prix | pgView | AI |
|-------|------|--------|-----|
| Solo | 19€/mois | ✅ | ❌ |
| Pro | 49€/mois | ✅ | 100 questions/mois |
| Premium | 89€/mois | ✅ | Illimité + agent autonome |

### Économie

```
Coût Claude API par question :    ~0.004€
100 questions/mois :              0.40€/client
Revenus Pro :                     49€/mois
Marge sur l'AI :                  99%

Même à 1000 questions/mois (Premium) :
  Coût : 4€, Revenu : 89€, Marge : 95%
```

---

## Pourquoi les SaaS classiques sont menacés

```
Avant l'AI :
  Valeur d'un SaaS = UI bien faite + features + données hébergées

Avec l'AI :
  L'UI devient secondaire (l'AI est l'interface)
  Les features deviennent du SQL (l'AI le génère)
  Les données restent la valeur (mais l'AI les rend accessibles partout)

Ce qui reste :
  ✓ Logique métier (règles, validations, workflows)
  ✓ Données structurées (schéma clair)
  ✓ Sécurité (RLS, tenant isolation)

Ce qui disparaît :
  ✗ L'UI comme différenciateur
  ✗ Les API custom comme barrière
  ✗ Le vendor lock-in sur les données
```

### L'avantage pgView dans ce monde

1. **La logique métier est en SQL** → l'AI la comprend nativement
2. **Le schéma est auto-documenté** → `pg_catalog` décrit tout
3. **Le MCP est le pont** → Claude pilote l'ERP directement
4. **pgView est le fallback visuel** → quand l'AI est overkill
5. **Coût marginal quasi nul** → SQL query < API call < UI render

---

## Feuille de route AI

```
Phase 0 (fait)      MCP workbench → Claude pilote l'ERP en dev
Phase 1 (1 jour)    Chat widget pgView → Edge Function → Claude → SQL
Phase 2 (1 semaine) Guardrails + actions métier + audit
Phase 3 (2 semaines) Agent WhatsApp/SMS via Twilio
Phase 4 (futur)     Voice → Whisper → Agent → Action
```

---

## Stack complet avec AI

```
┌──────────────────────────────────────────────────┐
│  Interfaces                                      │
│  ├── pgView (browser, dashboard, CRUD)           │
│  ├── Chat widget (questions en langage naturel)  │
│  ├── WhatsApp/SMS (agent autonome)               │
│  └── Claude Desktop (dev, via MCP)               │
├──────────────────────────────────────────────────┤
│  Intelligence                                    │
│  ├── Claude API (NL → SQL, formatting)           │
│  ├── Supabase Edge Functions (orchestration)     │
│  └── MCP plpgsql-workbench (dev tools)           │
├──────────────────────────────────────────────────┤
│  Backend                                         │
│  ├── PostgreSQL (données + logique + HTML)        │
│  ├── PostgREST (API HTTP)                        │
│  ├── RLS (isolation multi-tenant)                │
│  └── pg_net (webhooks sortants)                  │
├──────────────────────────────────────────────────┤
│  Hébergement                                     │
│  └── Supabase (25$/mois tout inclus)             │
└──────────────────────────────────────────────────┘
```
