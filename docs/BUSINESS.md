# Business Plan — SaaS pgView pour Artisans

> Ce document décrit le premier produit commercial construit sur la plateforme PL/pgSQL Workbench.
> Le workbench est la plateforme de développement de l'entreprise — chaque application est un ensemble de schemas PostgreSQL + tools MCP, packagé via des toolboxes pour distribution commerciale.

## Executive Summary

Application de gestion métier pour artisans (fumistes, menuisiers, plombiers, chauffagistes) construite entièrement en PostgreSQL. Le HTML est généré côté serveur par des fonctions PL/pgSQL (pgView), servi par PostgREST, affiché par un shell SPA de 50 lignes. Zéro framework JS, zéro serveur applicatif.

**Avantage concurrentiel** : coût de développement et de maintenance 10x inférieur à une app classique React/Node, avec les mêmes fonctionnalités.

**Développé en 4 heures** (MCP workbench + pgView + demo app + tests + spec).

---

## 1. Le Marché

### Taille

- ~1.3M artisans en France (source : CMA 2024)
- Marché logiciel BTP/artisan estimé à ~500M€/an
- Taux d'équipement en logiciel de gestion : ~30%
- 70% utilisent encore Excel ou papier

### Douleur

- Les ERP généralistes (Axonaut, Sellsy) sont trop complexes pour un artisan solo
- Les logiciels BTP (Batappli, Obat) sont chers (39-79€/mois) pour ce qu'ils offrent
- Pas de solution spécifique par métier (fumiste, menuisier, etc.)
- Obligation de facturation électronique en 2027 pour TPE/PME

### Opportunité

Un logiciel **simple, pas cher, spécifique au métier** qui fait devis → commande → facture → suivi client, sans superflu.

---

## 2. Le Produit

### Fonctionnalités

| Module | Fonctionnalités |
|--------|----------------|
| **Clients** | Fiche client, historique commandes, tier fidélité |
| **Catalogue** | Produits/services, prix, stock |
| **Devis** | Création, envoi, suivi, conversion en commande |
| **Commandes** | Workflow (pending → confirmed → shipped), annulation avec restore stock |
| **Facturation** | Génération facture, codes promo, remises fidélité |
| **Dashboard** | KPIs temps réel, top produits, alertes stock |
| **Remises** | Codes promo (%, fixe, buy-x-get-y), remises par tier |

### Roadmap

```
V1 (Semaine 1-4)      Clients, catalogue, devis, factures, dashboard
V2 (Mois 2-3)         Export comptable, TVA, facture électronique
V3 (Mois 4-6)         Planning chantiers, agenda, notifications
V4 (Mois 6+)          PWA mobile, mode hors-ligne, intégration Stripe
```

### Stack technique

```
PostgreSQL           Base de données + logique métier + rendu HTML
PostgREST            API HTTP automatique (1 endpoint : POST /rpc/page)
pgView               Moteur SSR en PL/pgSQL (la DB génère le HTML)
PicoCSS + marked.js  Style + Markdown côté client
Supabase             Hébergement managé (DB + PostgREST + Auth + Storage)

0 framework JS. 0 serveur applicatif. 0 build pipeline.
```

### Différenciation technique

| | App classique | pgView |
|---|--------------|--------|
| Temps de dev d'une feature | 1-3 jours | 15-60 min |
| Deploy | Build → CI → Docker → Kubernetes | `edit` → F5 → live (5ms) |
| Dépendances | 500+ packages npm | 0 |
| Maintenance | Updates sécurité, breaking changes | SQL ne vieillit pas |
| Coût hébergement | 50-150€/mois | 25$/mois |
| Portabilité | Vendor lock-in | `pg_dump` → anywhere |

---

## 3. Modèle de Revenus

### Pricing

| Offre | Prix/mois | Cible | Fonctionnalités |
|-------|-----------|-------|----------------|
| **Solo** | 19€ | Artisan seul | 1 user, devis + factures + clients |
| **Pro** | 39€ | TPE 2-5 pers. | 3 users, + dashboard, + exports, + remises |
| **Équipe** | 69€ | PME | Illimité, + multi-chantier, + compta |

- Sans engagement, mensuel
- Essai gratuit 14 jours
- Positionné **sous** la concurrence pour Solo (vs Tolteck 29€, Obat 39€)

### Panier moyen estimé : 35€/mois

Mix : 40% Solo (19€) + 45% Pro (39€) + 15% Équipe (69€) = ~35€

---

## 4. Structure de Coûts

### Coûts fixes

| Poste | Coût/mois |
|-------|-----------|
| Supabase Pro (multi-tenant) | 23€ |
| Domaine + DNS | 2€ |
| Email transactionnel (Resend/Postmark) | 5€ |
| **Total fixe** | **~30€/mois** |

### Coûts variables

| Poste | Coût/client/mois |
|-------|-----------------|
| Stripe (1.4% + 0.25€) | ~0.50€ |
| Supabase overages (au-delà de 200 clients) | ~0.15€ |
| Support (15 min/client/mois en moyenne) | temps |
| **Total variable** | **~0.65€/client/mois** |

### Marge brute : ~96%

```
Revenu moyen/client :  35€/mois
Coût variable/client :  0.65€/mois
Marge unitaire :       34.35€/mois (98%)
Coûts fixes :          30€/mois
Break-even :           1 client
```

---

## 5. Projections Financières

### Hypothèses d'acquisition

```
Mois 1-3    Réseau personnel, bouche à oreille     +2 clients/mois
Mois 4-6    SEO + forums artisans + content         +4 clients/mois
Mois 7-12   Recommandations + partenariats CMA      +6 clients/mois
Mois 13-24  Croissance organique + referral          +8 clients/mois

Churn mensuel : 5% (standard SaaS TPE)
```

### Projection mensuelle

| Mois | Nouveaux | Churn | Clients actifs | MRR | Coûts | Net |
|------|----------|-------|---------------|-----|-------|-----|
| 1 | 2 | 0 | 2 | 70€ | 31€ | 39€ |
| 3 | 2 | 0 | 8 | 280€ | 35€ | 245€ |
| 6 | 4 | 1 | 22 | 770€ | 44€ | 726€ |
| 9 | 6 | 2 | 38 | 1 330€ | 55€ | 1 275€ |
| 12 | 6 | 3 | 55 | 1 925€ | 66€ | 1 859€ |
| 18 | 8 | 4 | 88 | 3 080€ | 87€ | 2 993€ |
| 24 | 8 | 6 | 120 | 4 200€ | 108€ | 4 092€ |

### Projection annuelle

| | Année 1 | Année 2 | Année 3 |
|---|---------|---------|---------|
| Clients fin d'année | 55 | 120 | 200 |
| ARR (revenu annuel) | 23 100€ | 50 400€ | 84 000€ |
| Coûts infra | 540€ | 960€ | 1 440€ |
| Coûts Stripe | 330€ | 720€ | 1 200€ |
| **Résultat net** | **~22 200€** | **~48 700€** | **~81 400€** |
| **Marge nette** | **96%** | **97%** | **97%** |

### Scénarios

```
                    Pessimiste    Réaliste     Optimiste
                    ──────────    ────────     ─────────
Clients M12         25            55           100
Clients M24         45            120          250
ARR M24             19 000€       50 400€      105 000€
Temps support/sem   2h            5h           10h
Mode                Side project  Mi-temps     Plein temps
```

---

## 6. Investissement Initial

| Poste | Montant |
|-------|---------|
| Développement (ton temps, ~4 semaines) | 0€ (ou ~8 000€ valorisé à 500€/jour) |
| Supabase Pro (3 premiers mois) | 69€ |
| Domaine + landing page | 15€ |
| Stripe setup | 0€ |
| **Total cash nécessaire** | **~85€** |

Pas de levée de fonds. Pas de serveurs à acheter. Pas de cofondateur technique à trouver.

---

## 7. Concurrence

### Positionnement

```
Prix ↑
  │
  │  Batappli (79€)
  │  ●
  │         Axonaut (70€)
  │         ●
  │
  │     Obat (39€)       ← Nous : Pro (39€)
  │     ●                   ●
  │  Tolteck (29€)
  │  ●
  │              ← Nous : Solo (19€)
  │              ●
  │
  └──────────────────────────────→ Spécialisation métier
    Généraliste                    Spécifique
```

### Avantages vs concurrence

| Critère | ERP SaaS classique | ArtisanApp (pgView) |
|---------|-------------------|---------------------|
| Prix | 29-79€/mois | 19-39€/mois |
| Personnalisation | Non | Totale (on possède le code) |
| Propriété données | Chez le SaaS | Chez le client (exportable) |
| Portabilité | Aucune | `pg_dump` → n'importe quel Postgres |
| Time to feature | Semaines/mois (roadmap éditeur) | Heures (MCP edit → live) |
| Complexité | Trop de boutons | Exactement ce qu'il faut |
| Mobile | App native ou rien | Responsive (PicoCSS) |

### Moat (barrière à l'entrée)

- **Coût marginal quasi nul** : 0.65€/client, impossible à concurrencer sur le prix
- **Vitesse de développement** : une feature en 15 min grâce au MCP workbench
- **Spécialisation** : un logiciel par métier (fumiste, menuisier, plombier) avec le même socle
- **Lock-in inversé** : les clients PEUVENT partir (pg_dump), donc ils RESTENT (confiance)

---

## 8. Go-to-Market

### Phase 1 — Validation (Mois 1-2)

```
- Déployer la demo sur Supabase
- Trouver 3-5 beta testeurs dans le réseau
- Itérer sur le feedback (MCP edit → live en 5ms)
- Valider le pricing
```

### Phase 2 — Lancement (Mois 3-4)

```
- Landing page (1 page, hébergée sur Supabase Storage)
- SEO : "logiciel gestion fumiste", "logiciel devis artisan"
- Présence forums : LeBonArtisan, forums métiers
- Inscription chambres des métiers locales
```

### Phase 3 — Croissance (Mois 5+)

```
- Programme de parrainage (1 mois offert par filleul)
- Contenu : blog "gestion d'entreprise artisan"
- Partenariats CMA (chambres des métiers)
- Déclinaison par métier (même code, branding différent)
```

### Coût d'acquisition client estimé : 0-50€

Principalement organique (SEO, bouche à oreille, forums). Pas de budget pub initial.

---

## 9. Scalabilité

### Multi-tenant sur Supabase

```sql
-- Un seul projet Supabase, tous les clients dedans
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON orders
  USING (tenant_id = current_setting('app.tenant_id')::int);

-- 25$/mois pour 1 à 200 clients
-- Coût marginal : ~0.15€/client/mois au-delà
```

### Déclinaison par métier

```
Même codebase pgView, personnalisation par schema :

  fumiste/         → catalogue fumoirs, devis installation
  menuisier/       → catalogue bois, devis sur mesure
  plombier/        → interventions, contrats maintenance
  electricien/     → devis, conformité, certificats

Chaque métier = un schema PostgreSQL = un bounded context
Mutualisation du socle (auth, facturation, dashboard)
```

### Extensions PostgreSQL en production

```
Inclus Supabase :    plpgsql_check, pgTAP, pg_trgm, pgcrypto
À activer :          pg_net (webhooks), supa_audit (audit trail)
                     pg_jsonschema (validation), pg_cron (jobs)
```

### Packaging par Toolbox

Le packaging des offres est piloté par la base de données via le schema `workbench`.

```
Code (tool definitions)           ← source des tools (TypeScript/Awilix)
    ↓
  npm run sync-tools              ← étape de déploiement
    ↓
  workbench.toolbox_tool          ← source de vérité runtime
    ↓                ↓
  MCP workbench    MCP client     ← lisent la DB, montent les tools autorisés
```

**Modèle de données :**

```sql
workbench.toolbox          (name, description)           -- ex: solo, pro, equipe, admin
workbench.toolbox_tool     (toolbox_name, tool_name)     -- N:N, quels tools dans chaque toolbox
workbench.tenant           (id, name, toolbox_name)      -- chaque tenant → 1 toolbox
```

**Exemple de packaging par offre :**

| Toolbox | Tools | Offre |
|---------|-------|-------|
| `solo` | pg_query, pg_get, pg_search | 19€/mois |
| `pro` | solo + pg_explain, pg_doc, fs_peek | 39€/mois |
| `equipe` | pro + pg_coverage, pg_test, pg_dump | 69€/mois |
| `admin` | tous (15 tools) | dev / administration |

**Principes :**

- **DB = source de vérité** pour le packaging, pas le code
- **Pas de hiérarchie implicite** entre toolboxes — chaque toolbox liste explicitement ses tools (mapping N:N)
- **`npm run sync-tools`** peuple la toolbox `admin` depuis le code, les autres toolboxes sont gérées manuellement (SQL ou futur admin UI)
- **Multi-tenant** : le tenant est identifié par JWT (Supabase Auth), sa toolbox détermine les tools MCP exposés
- **Découplage total** : un même tool peut être dans plusieurs toolboxes, une toolbox custom peut être créée pour un client spécifique

---

## 10. Risques

| Risque | Probabilité | Impact | Mitigation |
|--------|------------|--------|------------|
| Churn élevé TPE | Moyen | Fort | Onboarding soigné, support réactif |
| Supabase augmente ses prix | Faible | Moyen | Portable vers tout Postgres (VPS + PostgREST) |
| Concurrence baisse les prix | Moyen | Faible | Marge 96%, on peut suivre |
| Obligation facture électronique | Certain | Opportunité | Feature V2, driver d'acquisition |
| Scaling au-delà de 500 clients | Faible (M24) | Moyen | Supabase Pro tient, sinon upgrade Team |

---

## 11. Métriques Clés

| Métrique | Cible M6 | Cible M12 | Cible M24 |
|----------|----------|-----------|-----------|
| MRR | 770€ | 1 925€ | 4 200€ |
| Clients actifs | 22 | 55 | 120 |
| Churn mensuel | <5% | <5% | <4% |
| NPS | >40 | >50 | >50 |
| Support/client/mois | <20 min | <15 min | <10 min |
| Coût acquisition | <30€ | <40€ | <50€ |

---

## Résumé

```
Investissement :     ~85€ cash + 4 semaines de dev
Break-even :         1 client (jour 1)
ARR Année 1 :        ~23 000€
ARR Année 2 :        ~50 000€
Marge :              96-97%
Moat :               Coût marginal quasi nul + vitesse de dev 10x
Stack :              PostgreSQL + PostgREST + pgView + Supabase
Risque financier :   Quasi inexistant
```

**La question n'est pas "est-ce que ça peut marcher", c'est "pourquoi personne ne l'a fait avant".**

La réponse : parce que personne n'avait un MCP workbench pour développer du PL/pgSQL à la vitesse de la pensée.

---

## 12. Intégration AI

L'AI n'est pas un risque pour ce modèle — c'est un accélérateur.

Le MCP workbench qu'on a construit EST l'interface AI ↔ ERP. Un LLM avec accès MCP peut déjà piloter l'app (queries, actions, dev). Pour les utilisateurs finaux, un chat widget (Edge Function + Claude API) permet l'interaction en langage naturel pour ~0.004€/question.

**Le modèle devient : pgView pour voir, AI pour agir.**

Voir [AI-INTEGRATION.md](AI-INTEGRATION.md) pour l'architecture complète, le code, et la feuille de route.
