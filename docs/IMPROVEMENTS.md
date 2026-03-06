# Verified Services Marketplace: Improvements & Technology Roadmap

**Last Updated:** March 2026
**Scope:** Architecture improvements, technology upgrades, and industry trend alignment

---

## Product Overview

The Verified Services Marketplace is a three-sided marketplace platform connecting vetted service providers with end customers through a trust-first architecture. A platform operator acts as the trust layer, controlling supply quality via automated verification workflows (licenses, insurance, background checks) while customers select from the verified provider pool through job posting, matching, and bidding.

Built for a national real estate services client processing 800+ monthly service requests across 12 metro markets, the platform achieved a 4x throughput increase, 90% faster provider verification (48h vs. 2-3 weeks), and a 3.9x improvement in repeat booking rate (58% vs. 15%). Year 1 GMV exceeded $15M.

The architecture generalizes to any domain where supply-side trust is the core value proposition: home services, healthcare staffing, legal referrals, and consulting networks.

---

## Current Architecture

### Tech Stack

| Layer | Technology | Version/Details |
|---|---|---|
| **Frontend** | Next.js 14 + shadcn/ui | Three portals (customer, provider, operator) |
| **API** | FastAPI (Python) | Async, Pydantic v2 validation |
| **Database** | PostgreSQL 15 + PostGIS 3.3 (Supabase) | Relational + geospatial |
| **Auth** | Clerk | Multi-tenant, role-based (customer/provider/operator) |
| **Payments** | Stripe Connect | Escrow via manual capture, split payments |
| **Background Checks** | Checkr API | Webhook-based, async verification |
| **Task Queue** | Trigger.dev | Long-running matching & onboarding jobs |
| **Workflow Automation** | n8n | Provider verification, bid notifications |
| **Email** | React Email + SendGrid | Transactional templates |
| **SMS** | Twilio | Provider notifications |
| **Push** | FCM (Firebase Cloud Messaging) | Mobile notifications |
| **Cache/Queue** | Redis 7 | Rate limiting, session cache, matching queue |
| **File Storage** | Supabase Storage | Documents, photos, certificates |
| **Deployment** | Vercel (frontend) + Docker (API) | Node 20.x, Python 3.11 |
| **Monitoring** | Sentry + Datadog | Errors + APM |

### Key Components

1. **Matching Engine** (`src/matching/matching_engine.py`): PostGIS radius filtering with composite scoring (rating 35%, completion rate 25%, response time 20%, tier 15%, recency 5%). Performance target: <200ms.

2. **Provider Verifier** (`src/verification/provider_verifier.py`): Multi-step pipeline -- Checkr identity/background, state licensing board API lookup (34 states automated), ACORD insurance certificate parsing, credential expiration monitoring.

3. **Escrow Manager** (`src/payments/escrow_manager.py`): Stripe Connect manual capture for escrow holds. Fee structure: 5% customer fee, 15% standard / 12% elite provider fee. Platform absorbs Stripe processing (2.9% + $0.30).

4. **Review System** (`src/ratings/review_system.py`): Weighted composite ratings (quality 50%, timeliness 30%, communication 20%). Double-blind reviews, recency weighting (90-day 2x multiplier), tier evaluation, anti-gaming anomaly detection.

5. **Marketplace Health** (`src/analytics/marketplace_health.py`): Composite health index (0-100), Gini coefficient for earnings fairness, market-level diagnostics with intervention playbooks.

6. **Database Schema** (`schema/schema.sql`): 13 tables with GIST indexes for geospatial queries, partial B-tree indexes, materialized views for provider availability and marketplace health metrics.

---

## Recommended Improvements

### 1. Upgrade Python Runtime and Dependencies

**Current State:** Python 3.11 (Dockerfile), FastAPI 0.115.0, Pydantic 2.10.0, SQLAlchemy 2.0.36.

**Recommendation:** Upgrade to Python 3.12+ for 5-15% performance improvement from the PEP 709 comprehension inlining and continued interpreter optimizations.

```
# requirements.txt updates
fastapi>=0.115.0     # Already current -- maintain latest
uvicorn>=0.32.0      # Upgrade for HTTP/2 and performance
pydantic>=2.10.0     # Already current
sqlalchemy>=2.0.36   # Already current
psycopg[binary]>=3.2 # Replace psycopg2-binary with psycopg 3 (async native)
stripe>=11.0.0       # Major version upgrade with improved typing
```

**Why:** `psycopg2-binary` is synchronous. Replacing it with `psycopg` v3 (`psycopg[binary]>=3.2`) provides native async support that aligns with FastAPI's async architecture. The current codebase uses `asyncpg` in `stripe/marketplace_payments.py` but `psycopg2-binary` in `requirements.txt` -- this inconsistency should be resolved.

**Code Reference:** `requirements.txt` line 4 (`psycopg2-binary==2.9.9`), `stripe/marketplace_payments.py` line 13 (`import asyncpg`).

---

### 2. Replace Celery + Redis Queue with Trigger.dev v3

**Current State:** The README mentions Celery + Redis for async workflows, but the actual implementation uses Trigger.dev (in `trigger-jobs/`). The architecture has an inconsistency between documented and implemented task orchestration.

**Recommendation:** Fully standardize on Trigger.dev v3, which has matured significantly. Remove Celery references from documentation and consolidate all background jobs:

- Matching engine (already implemented in `trigger-jobs/matching_engine.ts`)
- Provider onboarding (already implemented in `trigger-jobs/provider_onboarding.ts`)
- Credential expiration monitoring (currently a placeholder in `provider_verifier.py` line 504)
- Double-blind review reveals (currently a placeholder in `review_system.py` line 386)
- Payout status bulk updates (currently in `stripe/marketplace_payments.py` line 536)
- Monthly tier evaluations (referenced in `review_system.py` line 337)

**Why:** Trigger.dev v3 provides durable execution with automatic retries, built-in scheduling (cron), step-level observability, and long-running job support (up to 24 hours). This eliminates the need for a separate Celery worker process and Redis as a broker.

**Reference:** https://trigger.dev/docs/v3

---

### 3. Add Full-Text and Semantic Search for Service Discovery

**Current State:** Service matching relies entirely on PostGIS radius queries and category-based filtering (`schema/schema.sql` line 113). Customers must select a predefined category -- there is no free-text search.

**Recommendation:** Integrate a search engine for service discovery:

**Option A -- Typesense (recommended):**
- Open-source, typo-tolerant, instant search
- Geo-search built in (supports `filter_by: location:(lat, lng, radius_km)`)
- Simpler operational footprint than Elasticsearch
- Version: Typesense 27.x (latest)
- NPM: `typesense` v2.x
- Reference: https://typesense.org/docs/

**Option B -- Meilisearch:**
- Rust-based, excellent for marketplace search UX
- Built-in geo-sorting and filtering
- Version: Meilisearch 1.x
- Reference: https://www.meilisearch.com/docs

**Implementation:**
- Index provider profiles, service categories, and historical request descriptions
- Enable natural language queries: "plumber near me who does water heater installation"
- Sync from PostgreSQL via Supabase database webhooks or pg_notify

**Code Reference:** `schema/schema.sql` lines 75-95 (`service_categories` and `provider_services` tables) -- these are the primary entities that need indexing.

---

### 4. Implement Real-Time Bidding with Supabase Realtime v2

**Current State:** The README mentions Supabase Realtime for bid notifications, but the actual notification dispatch is done via SendGrid email, Twilio SMS, and FCM push in `trigger-jobs/matching_engine.ts` (lines 148-221). There is no WebSocket-based real-time bidding UI.

**Recommendation:** Implement Supabase Realtime Broadcast and Presence for the bidding experience:

```typescript
// Real-time bid updates for customers
const channel = supabase.channel(`request:${requestId}`)
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'bids',
    filter: `request_id=eq.${requestId}`,
  }, (payload) => {
    // Update bid list in real-time
    addBidToUI(payload.new);
  })
  .on('presence', { event: 'sync' }, () => {
    // Show how many providers are viewing this request
    const state = channel.presenceState();
    updateViewerCount(Object.keys(state).length);
  })
  .subscribe();
```

**Why:** Real-time bid visibility creates urgency and improves the customer experience. Showing "3 providers are viewing your request" and live bid updates increases engagement and reduces time-to-first-bid. Supabase Realtime v2 supports Broadcast (pub/sub), Presence (online status), and Postgres Changes (CDC).

---

### 5. Add AI-Powered Document Verification (OCR + LLM)

**Current State:** Insurance certificate parsing is described as needing OCR in production (`provider_verifier.py` lines 376-412) with a reference to Google Cloud Vision or AWS Textract. The current implementation returns mock data.

**Recommendation:** Use a modern document AI pipeline:

**Primary:** Google Document AI (specialized for ACORD forms)
- Pre-built processors for insurance certificates
- High accuracy on structured/semi-structured forms
- Reference: https://cloud.google.com/document-ai

**Alternative:** AWS Textract Lending + Anthropic Claude for complex parsing
- Textract extracts form fields; Claude validates and cross-references
- Handles edge cases like handwritten amendments on ACORD forms

**LLM Enhancement:** Use an LLM (Claude API or GPT-4) to validate extracted data:
```python
# After OCR extraction, validate with LLM
prompt = f"""
Validate this insurance certificate extraction:
- Named Insured: {extracted['named_insured']}
- Policy Number: {extracted['policy_number']}
- GL Per Occurrence: ${extracted['gl_per_occurrence']:,}
- Expiration: {extracted['expiration_date']}

Provider name on file: {provider.business_name}

Questions:
1. Does the named insured match the provider? (exact or DBA match)
2. Is the coverage amount >= $1,000,000?
3. Is the policy currently active?
Return JSON with match_confidence (0-1) and any discrepancies.
"""
```

**Code Reference:** `src/verification/provider_verifier.py` lines 316-412 (`_verify_insurance` and `parse_acord_certificate` methods).

---

### 6. Implement Feature Flags with LaunchDarkly or Statsig

**Current State:** There is a `feature_flags/` directory in the project root but it appears empty or contains no implementation. Feature flags are critical for a marketplace where you need to roll out changes to specific markets, provider tiers, or customer segments.

**Recommendation:** Implement Statsig (recommended for marketplace analytics integration):

- Version: Statsig Server SDK v1.x
- Built-in A/B testing and experimentation
- Feature gates with targeting rules (by market, tier, user segment)
- Metrics integration -- directly measure impact on marketplace health metrics
- Reference: https://docs.statsig.com/

**Key Feature Flags to Implement:**
```
matching_algorithm_v2          # Test new matching weights
expanded_radius_auto           # Auto-expand radius for low-coverage markets
elite_tier_lower_fee           # Test 10% vs 12% elite fee
instant_book                   # Skip bidding for repeat customer-provider pairs
ai_document_verification       # Roll out AI-based insurance parsing
review_sentiment_analysis      # NLP-powered review quality scoring
```

---

### 7. Add Observability Stack Upgrades

**Current State:** The ARCHITECTURE.md references Sentry (errors) and Datadog (APM), but there is no implementation of structured logging, distributed tracing, or custom metrics in the codebase.

**Recommendation:** Implement OpenTelemetry for vendor-agnostic observability:

```python
# FastAPI + OpenTelemetry auto-instrumentation
# requirements.txt additions:
# opentelemetry-api>=1.28.0
# opentelemetry-sdk>=1.28.0
# opentelemetry-instrumentation-fastapi>=0.49b0
# opentelemetry-instrumentation-psycopg>=0.49b0
# opentelemetry-exporter-otlp>=1.28.0

from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

tracer = trace.get_tracer("marketplace.matching")

async def match_providers(request: ServiceRequest):
    with tracer.start_as_current_span("matching.pipeline") as span:
        span.set_attribute("marketplace.request_id", request.id)
        span.set_attribute("marketplace.category", request.category_id)
        span.set_attribute("marketplace.radius_miles", request.matching_radius_miles)

        # ... matching logic
        span.set_attribute("marketplace.candidates_found", len(candidates))
        span.set_attribute("marketplace.match_score_top", top_score)
```

**Custom Marketplace Metrics to Track:**
- `marketplace.matching.latency_ms` -- matching engine p50/p95/p99
- `marketplace.bid.coverage_rate` -- percentage of requests with 3+ bids
- `marketplace.escrow.hold_duration_hours` -- time funds sit in escrow
- `marketplace.verification.pipeline_duration_hours` -- end-to-end verification time
- `marketplace.gini_coefficient` -- weekly earnings distribution

**Recommended Backend:** Grafana Cloud (includes Tempo for traces, Loki for logs, Prometheus for metrics) or Axiom (simpler, modern alternative).

- Axiom reference: https://axiom.co/docs
- OpenTelemetry reference: https://opentelemetry.io/docs/

---

### 8. Strengthen the Matching Algorithm with ML

**Current State:** The matching engine uses static weights (`matching_engine.py` lines 36-42): rating 35%, completion rate 25%, response time 20%, tier 15%, recency 5%. These were presumably tuned manually.

**Recommendation:** Implement a two-phase approach:

**Phase 1 -- Contextual Bandit (near-term):**
Use a contextual bandit algorithm to dynamically adjust matching weights based on historical conversion data (bid accepted --> job completed --> positive review).

```python
# Multi-armed bandit for weight optimization
# Library: vowpalwabbit (VW) or custom Thompson Sampling
import numpy as np

class AdaptiveMatchingWeights:
    """Thompson Sampling for matching weight optimization."""

    def __init__(self):
        # Prior: Beta(alpha, beta) for each weight dimension
        self.arms = {
            "rating_heavy":    {"weights": {"rating": 0.45, "completion": 0.20, "response": 0.15, "tier": 0.15, "recency": 0.05}, "alpha": 1, "beta": 1},
            "completion_heavy": {"weights": {"rating": 0.25, "completion": 0.40, "response": 0.15, "tier": 0.15, "recency": 0.05}, "alpha": 1, "beta": 1},
            "response_heavy":  {"weights": {"rating": 0.30, "completion": 0.20, "response": 0.30, "tier": 0.15, "recency": 0.05}, "alpha": 1, "beta": 1},
            "balanced":        {"weights": {"rating": 0.35, "completion": 0.25, "response": 0.20, "tier": 0.15, "recency": 0.05}, "alpha": 1, "beta": 1},
        }

    def select_weights(self, market: str, category: str) -> dict:
        """Select weight configuration using Thompson Sampling."""
        samples = {
            name: np.random.beta(arm["alpha"], arm["beta"])
            for name, arm in self.arms.items()
        }
        best_arm = max(samples, key=samples.get)
        return self.arms[best_arm]["weights"]

    def update(self, arm_name: str, reward: float):
        """Update arm based on outcome (1 = job completed with 4+ rating, 0 = otherwise)."""
        if reward > 0:
            self.arms[arm_name]["alpha"] += 1
        else:
            self.arms[arm_name]["beta"] += 1
```

**Phase 2 -- Learning to Rank (medium-term):**
Train a LightGBM or XGBoost model on historical matching-to-completion data:
- Features: provider metrics, request attributes, distance, time of day, market density
- Label: successful completion with positive review
- Library: `lightgbm>=4.5.0`
- Reference: https://lightgbm.readthedocs.io/

---

### 9. Add API Rate Limiting and Caching Layer

**Current State:** Rate limiting is mentioned in the architecture (Redis-based) but not implemented in the codebase. The `docker-compose.yml` provisions Redis but no rate limiting middleware exists.

**Recommendation:** Implement rate limiting with `slowapi` and add response caching:

```python
# requirements.txt addition:
# slowapi>=0.1.9

from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(
    key_func=get_remote_address,
    storage_uri="redis://redis:6379/1",
    default_limits=["100/minute"],
)

# Per-endpoint limits
@app.get("/api/v1/providers/search")
@limiter.limit("30/minute")  # Search is expensive (PostGIS)
async def search_providers(request: Request):
    ...

@app.post("/api/v1/bids")
@limiter.limit("10/minute")  # Prevent bid spam
async def submit_bid(request: Request):
    ...
```

**Caching:** Use Redis for caching materialized view data and frequently accessed provider profiles:
```python
# Cache provider availability (refresh every 5 minutes)
@cached(ttl=300, cache=RedisCache, key="provider_availability:{market}")
async def get_provider_availability(market: str):
    ...
```

---

### 10. Implement Webhook Signature Verification

**Current State:** The Stripe webhook handler in `stripe/marketplace_payments.py` (line 630) processes events but does not verify webhook signatures. The Checkr webhook handler in `provider_verifier.py` similarly lacks signature verification.

**Recommendation:** Add signature verification for all incoming webhooks:

```python
# Stripe webhook verification
import stripe

@app.post("/api/webhooks/stripe")
async def stripe_webhook(request: Request):
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")

    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, os.getenv("STRIPE_WEBHOOK_SECRET")
        )
    except stripe.error.SignatureVerificationError:
        raise HTTPException(status_code=400, detail="Invalid signature")

    await handle_stripe_webhook(event)
```

**Code Reference:** `stripe/marketplace_payments.py` line 630 (`handle_stripe_webhook` function) -- currently accepts raw dict, no verification.

---

### 11. Database Schema Improvements

**Current State:** The schema (`schema/schema.sql`) is well-designed with appropriate indexes and materialized views, but has several areas for improvement.

**Recommendations:**

**a) Add Row-Level Security (RLS) Policies:**
The schema mentions RLS in documentation but does not implement it. Supabase relies on RLS for data access control.

```sql
-- Enable RLS on all tables
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;

-- Customers can only see their own data
CREATE POLICY "customers_own_data" ON customers
  FOR ALL USING (user_id = auth.uid());

-- Providers can see requests matched to them
CREATE POLICY "providers_see_matched_requests" ON service_requests
  FOR SELECT USING (
    id IN (
      SELECT request_id FROM matched_providers
      WHERE provider_id IN (
        SELECT id FROM providers WHERE user_id = auth.uid()
      )
    )
  );

-- Operators can see everything
CREATE POLICY "operators_full_access" ON service_requests
  FOR ALL USING (
    auth.uid() IN (
      SELECT user_id FROM operators WHERE is_active = true
    )
  );
```

**b) Add `provider_availability` as a regular table with triggers instead of a materialized view:**
The materialized view (`schema/schema.sql` line 452) requires manual refresh. Replace with a regular table updated by triggers on `service_requests` status changes.

**c) Add composite indexes for common query patterns:**
```sql
-- Matching query optimization
CREATE INDEX idx_matching_composite ON providers (
  verification_status, is_active, tier
) INCLUDE (composite_rating, completion_rate, avg_response_minutes)
WHERE verification_status = 'verified' AND is_active = true;

-- Review lookup for rating calculation
CREATE INDEX idx_reviews_provider_visible ON reviews (
  provider_id, created_at DESC
) WHERE is_visible = true;
```

---

### 12. Add End-to-End Type Safety

**Current State:** The codebase mixes Python (API, business logic) and TypeScript (Trigger.dev jobs, Clerk auth, emails). The TypeScript code defines its own interfaces that duplicate the Python dataclasses and SQL schema.

**Recommendation:** Generate types from a single source of truth:

**Option A -- Supabase CLI type generation (recommended):**
```bash
supabase gen types typescript --project-id $PROJECT_ID > src/types/database.ts
```
This generates TypeScript types directly from the PostgreSQL schema.

**Option B -- Add Zod schemas with `zod-to-json-schema` for cross-language validation:**
```typescript
// Shared Zod schemas
import { z } from "zod";

export const ServiceRequestSchema = z.object({
  id: z.string().uuid(),
  category_id: z.string().uuid(),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  matching_radius_miles: z.number().int().min(5).max(100).default(25),
  // ... generated from schema.sql
});
```

---

## New Technologies & Trends

### 1. Verifiable Credentials (W3C Standard) for Provider Trust

**What:** W3C Verifiable Credentials (VCs) are a standard for cryptographically secure, tamper-proof digital credentials. Instead of the platform storing copies of licenses and insurance certificates, providers carry verifiable digital credentials in a wallet.

**Why for this product:** The current verification pipeline (`provider_verifier.py`) manually checks state licensing boards and parses ACORD forms. With VCs, a state licensing board would issue a digital credential directly to the provider, and the platform can verify it instantly without calling external APIs.

**How:**
- Integrate with credential issuance networks (e.g., Dock.io, Trinsic, SpruceID)
- Accept verifiable credentials alongside traditional document uploads
- Reduce verification time from 48 hours to near-instant for VC-backed credentials
- W3C spec: https://www.w3.org/TR/vc-data-model-2.0/
- Trinsic SDK: https://docs.trinsic.id/ (supports Node.js and Python)

**Timeline:** Emerging -- suitable for Phase 3+ (2027+). State licensing boards are beginning pilot programs.

---

### 2. AI-Powered Dispute Resolution

**What:** Use LLMs to assist with dispute resolution by analyzing photo evidence, reviewing conversation history, and suggesting resolution outcomes based on precedent.

**Why for this product:** The PRD mentions dispute resolution was a pain point (built in Phase 3 instead of Phase 2, causing 15+ hours of manual intervention in month 1). An AI-assisted workflow would reduce operator burden.

**How:**
- Use Claude API or GPT-4 Vision to analyze before/after job photos
- Train a classification model on historical dispute outcomes
- Generate a recommended resolution with confidence score for operator review
- Libraries: `anthropic>=0.39.0` (Claude API), `openai>=1.55.0`
- Reference: https://docs.anthropic.com/en/docs/vision

---

### 3. Embedded Finance: Instant Payouts and Provider Lending

**What:** Stripe Treasury and Stripe Issuing enable platforms to offer financial products to providers -- instant payouts, business debit cards, and working capital loans.

**Why for this product:** The platform already reduced payment cycles from 30-60 days to 3-5 days. Offering instant payouts (same-day or next-day) would further differentiate the platform and increase provider retention.

**How:**
- **Stripe Instant Payouts**: Enable providers to cash out immediately for a small fee (1% typical)
- **Stripe Treasury**: Offer provider bank accounts within the platform
- **Stripe Capital**: Offer working capital loans based on platform earnings history
- Reference: https://stripe.com/docs/treasury
- Reference: https://stripe.com/docs/connect/instant-payouts

---

### 4. Vector Search for Smart Matching

**What:** Use vector embeddings to match service requests to providers based on semantic similarity rather than just category IDs.

**Why for this product:** The current matching pipeline (`matching_engine.py` line 86) filters by `category_id` as the first step. This misses cross-category matches (e.g., a "general contractor" who could handle a "plumbing" request). Vector search enables fuzzy, semantic matching.

**How:**
- Use Supabase `pgvector` extension (already available in Supabase)
- Generate embeddings for provider skill descriptions and request descriptions
- Use cosine similarity in the matching pipeline as a pre-filter or ranking signal

```sql
-- Enable pgvector
CREATE EXTENSION IF NOT EXISTS vector;

-- Add embedding columns
ALTER TABLE providers ADD COLUMN skills_embedding vector(1536);
ALTER TABLE service_requests ADD COLUMN description_embedding vector(1536);

-- Semantic matching query
SELECT p.id, p.business_name,
  1 - (p.skills_embedding <=> sr.description_embedding) AS semantic_similarity
FROM providers p, service_requests sr
WHERE sr.id = $request_id
  AND 1 - (p.skills_embedding <=> sr.description_embedding) > 0.7
ORDER BY semantic_similarity DESC;
```

- Embedding model: OpenAI `text-embedding-3-small` or Cohere `embed-english-v3.0`
- Supabase pgvector reference: https://supabase.com/docs/guides/ai/vector-columns

---

### 5. Edge Functions for Low-Latency Matching

**What:** Run matching logic at the edge (Supabase Edge Functions, Vercel Edge Functions, or Cloudflare Workers) to reduce latency for geographically distributed markets.

**Why for this product:** The matching engine targets <200ms end-to-end. Edge deployment could cut this to <50ms by running scoring logic close to the user while the PostGIS query runs in the database region.

**How:**
- Deploy the scoring/ranking logic as a Supabase Edge Function (Deno runtime)
- Keep PostGIS queries in the database (can't move spatial queries to edge)
- Use edge-cached provider availability data for initial filtering
- Reference: https://supabase.com/docs/guides/functions

---

### 6. Progressive Web App (PWA) for Provider Mobile Experience

**What:** Convert the provider portal into a PWA with offline support, push notifications via Web Push API, and home screen installation.

**Why for this product:** Providers are mobile-first (contractors in the field). The current architecture uses FCM for push (`trigger-jobs/matching_engine.ts` line 185), which requires a native app wrapper. A PWA eliminates the app store dependency.

**How:**
- Add service worker for offline bid viewing and job details caching
- Use `next-pwa` (v14+) or `@ducanh2912/next-pwa` for Next.js PWA support
- Implement Background Sync for bid submissions when offline
- Reference: https://web.dev/learn/pwa

---

### 7. Compliance Automation: SOC 2 and Data Privacy

**What:** Automated compliance tooling for SOC 2 Type II, CCPA, and data privacy requirements.

**Why for this product:** The platform handles PII (names, addresses, SSNs via Checkr), financial data (Stripe), and background check results. As it scales to more markets, compliance requirements increase.

**How:**
- **Vanta** or **Drata**: Automated SOC 2 compliance monitoring
- **OneTrust** or **Transcend**: Privacy request automation (CCPA/GDPR data subject requests)
- Implement data retention policies in the schema (auto-archive audit_log older than 7 years)
- Add PII encryption at rest for the `verifications` table (`document_url`, `document_number` columns)
- Reference: https://www.vanta.com/

---

### 8. Event-Driven Architecture with Change Data Capture

**What:** Use PostgreSQL logical replication or Debezium to stream database changes as events, enabling loosely coupled microservices.

**Why for this product:** The current architecture has tight coupling between components. For example, when a bid is submitted, the matching engine must update the request, notify the customer, and check bid coverage -- all in the same Trigger.dev job. CDC enables each concern to react independently.

**How:**
- Use Supabase Realtime (already provisioned) for Postgres CDC
- Or add Debezium with Apache Kafka / Redpanda for more complex event routing
- Events to capture: `bid.created`, `payment.captured`, `review.submitted`, `verification.completed`
- Simpler alternative: Inngest (https://www.inngest.com/) for event-driven serverless functions

---

## Priority Roadmap

### P0 -- Critical (Next Sprint)

| # | Improvement | Effort | Impact |
|---|---|---|---|
| 1 | **Webhook signature verification** (Stripe, Checkr) | 1 day | Security: prevents spoofed webhook attacks |
| 2 | **Add RLS policies to Supabase schema** | 2 days | Security: prevents unauthorized data access |
| 3 | **Fix psycopg2/asyncpg inconsistency** -- standardize on psycopg v3 | 1 day | Reliability: resolves mixed sync/async DB access |
| 4 | **Implement rate limiting** with slowapi + Redis | 1 day | Security: prevents API abuse |

### P1 -- High (Next 2-4 Weeks)

| # | Improvement | Effort | Impact |
|---|---|---|---|
| 5 | **Real-time bidding UI** with Supabase Realtime | 1 week | UX: live bid updates improve customer engagement |
| 6 | **OpenTelemetry instrumentation** for matching engine | 3 days | Ops: visibility into matching performance |
| 7 | **Feature flags** with Statsig or LaunchDarkly | 3 days | Velocity: safe rollouts per market |
| 8 | **Database index optimization** (composite indexes, convert MV to table+trigger) | 2 days | Performance: faster matching queries |
| 9 | **Type generation** from Supabase schema | 1 day | DX: eliminates type drift between TS and Python |
| 10 | **Consolidate task orchestration** on Trigger.dev v3 (remove Celery references) | 2 days | Simplicity: single task runtime |

### P2 -- Medium (Next 1-3 Months)

| # | Improvement | Effort | Impact |
|---|---|---|---|
| 11 | **AI document verification** (ACORD form OCR + LLM validation) | 2 weeks | Automation: reduces manual insurance review |
| 12 | **Full-text search** with Typesense | 1 week | UX: natural language service discovery |
| 13 | **Adaptive matching weights** (contextual bandit) | 2 weeks | Revenue: optimizes for successful completions |
| 14 | **Stripe Instant Payouts** for providers | 1 week | Retention: same-day payouts increase provider loyalty |
| 15 | **PWA for provider portal** | 1 week | UX: mobile-first experience without app stores |
| 16 | **Compliance automation** (Vanta/Drata + data encryption) | 2 weeks | Trust: SOC 2 readiness for enterprise clients |

### P3 -- Future (3-6+ Months)

| # | Improvement | Effort | Impact |
|---|---|---|---|
| 17 | **Vector search (pgvector)** for semantic matching | 2 weeks | Matching: cross-category fuzzy matching |
| 18 | **AI dispute resolution** assistant | 3 weeks | Ops: reduces operator dispute handling time |
| 19 | **Learning to Rank** ML model for matching | 4 weeks | Revenue: data-driven matching optimization |
| 20 | **Verifiable Credentials** integration | 4 weeks | Trust: cryptographic proof of provider qualifications |
| 21 | **Event-driven architecture** with CDC | 3 weeks | Architecture: decoupled, scalable services |
| 22 | **Edge functions** for low-latency matching | 2 weeks | Performance: sub-50ms matching in all markets |
| 23 | **Stripe Treasury** for provider banking | 4 weeks | Retention: embedded financial services |
| 24 | **Multi-language support** (i18n) for market expansion | 3 weeks | Growth: international market readiness |

---

## Technology Reference Summary

| Technology | Purpose | Version | Link |
|---|---|---|---|
| Typesense | Full-text + geo search | 27.x | https://typesense.org |
| pgvector | Vector similarity search | 0.8.x | https://github.com/pgvector/pgvector |
| OpenTelemetry | Observability (traces, metrics, logs) | 1.28+ | https://opentelemetry.io |
| Statsig | Feature flags + experimentation | SDK v1.x | https://statsig.com |
| LightGBM | Learning to Rank for matching | 4.5+ | https://lightgbm.readthedocs.io |
| psycopg | Async PostgreSQL driver (replaces psycopg2) | 3.2+ | https://www.psycopg.org/psycopg3 |
| slowapi | FastAPI rate limiting | 0.1.9+ | https://github.com/laurentS/slowapi |
| Trigger.dev | Background jobs + scheduling | v3 | https://trigger.dev |
| Axiom | Log management + observability | - | https://axiom.co |
| Grafana Cloud | Metrics, traces, logs (OSS stack) | - | https://grafana.com/cloud |
| Supabase Edge Functions | Edge compute (Deno) | - | https://supabase.com/edge-functions |
| next-pwa | PWA support for Next.js | 5.x+ | https://github.com/shadowwalker/next-pwa |
| Trinsic | Verifiable Credentials SDK | v2 | https://trinsic.id |
| Vanta | Automated SOC 2 compliance | - | https://vanta.com |
| Inngest | Event-driven serverless functions | v3 | https://inngest.com |
| Google Document AI | OCR for ACORD forms | v1 | https://cloud.google.com/document-ai |
| Anthropic Claude API | AI validation, dispute analysis | v1 | https://docs.anthropic.com |
| Stripe Treasury | Embedded banking for providers | - | https://stripe.com/treasury |
| Stripe Instant Payouts | Same-day provider payouts | - | https://stripe.com/connect/instant-payouts |

---

*This document should be reviewed quarterly and updated as the marketplace scales and new technologies emerge.*
