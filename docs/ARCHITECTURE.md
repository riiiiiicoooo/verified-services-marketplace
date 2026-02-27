# System Architecture: Verified Services Marketplace

**Last Updated:** January 2025

---

## 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          CLIENT LAYER                                    │
│                                                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐       │
│  │ Customer App  │    │ Provider App  │    │ Operator Dashboard   │       │
│  │ (Next.js)     │    │ (Next.js)     │    │ (Next.js)            │       │
│  │               │    │               │    │                      │       │
│  │ Post requests │    │ View jobs     │    │ Verify providers     │       │
│  │ Review bids   │    │ Submit bids   │    │ Monitor metrics      │       │
│  │ Book + pay    │    │ Track earnings│    │ Resolve disputes     │       │
│  │ Rate providers│    │ Manage profile│    │ Configure platform   │       │
│  └───────┬───────┘    └───────┬───────┘    └──────────┬───────────┘       │
│          │                    │                        │                  │
└──────────┼────────────────────┼────────────────────────┼──────────────────┘
           │                    │                        │
           └────────────────────┼────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          API GATEWAY (FastAPI)                            │
│                                                                          │
│  Authentication (Supabase JWT)  │  Rate Limiting (Redis)                 │
│  Role-Based Routing             │  Request Validation (Pydantic)         │
│  API Versioning (/api/v1/)      │  Error Handling + Logging              │
└───────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┘
        │          │          │          │          │          │
        ▼          ▼          ▼          ▼          ▼          ▼
┌──────────┐┌──────────┐┌──────────┐┌──────────┐┌──────────┐┌──────────┐
│ Request  ││ Matching ││ Payment  ││ Verifi-  ││ Review   ││ Analytics│
│ Service  ││ Engine   ││ Service  ││ cation   ││ Service  ││ Service  │
│          ││          ││          ││ Service  ││          ││          │
│ CRUD     ││ Filter   ││ Stripe   ││ Checkr   ││ Ratings  ││ Health   │
│ Status   ││ Rank     ││ Connect  ││ License  ││ Composite││ Liquidity│
│ mgmt     ││ Notify   ││ Escrow   ││ APIs     ││ scoring  ││ GMV      │
│ Search   ││ Capacity ││ Payouts  ││ Insurance││ Modera-  ││ Funnel   │
│          ││          ││ Refunds  ││ Manual   ││ tion     ││ Reports  │
│          ││          ││ 1099s    ││ queue    ││          ││          │
└──────────┘└──────────┘└──────────┘└──────────┘└──────────┘└──────────┘
        │          │          │          │          │          │
        └──────────┴──────────┴──────────┴──────────┴──────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          DATA LAYER                                      │
│                                                                          │
│  ┌─────────────────────┐  ┌──────────────┐  ┌────────────────────────┐  │
│  │ PostgreSQL + PostGIS │  │ Redis        │  │ Supabase Storage       │  │
│  │ (Supabase)           │  │              │  │                        │  │
│  │                      │  │ Matching     │  │ License documents      │  │
│  │ Relational data      │  │ queue        │  │ Insurance certificates │  │
│  │ Geospatial queries   │  │ Rate limits  │  │ Portfolio photos       │  │
│  │ RLS (role-based)     │  │ Session cache│  │ Job photos             │  │
│  │ Realtime (WebSocket) │  │ Notifications│  │ Profile images         │  │
│  └─────────────────────┘  └──────────────┘  └────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       EXTERNAL SERVICES                                  │
│                                                                          │
│  Stripe Connect      Checkr           SendGrid     Twilio     FCM       │
│  (Payments)          (Background)     (Email)      (SMS)      (Push)    │
│                                                                          │
│  State Licensing     Google Maps      Sentry       Datadog              │
│  Board APIs          (Geocoding)      (Errors)     (APM)               │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Core Services

### 2.1 Request Service

Handles the full lifecycle of a service request from creation through completion.

```
Customer posts request
        │
        ▼
┌─────────────────┐
│ Validate input   │  Category, location, description, dates
│ Geocode address  │  Google Maps → lat/lng stored with PostGIS
│ Store request    │  Status: open
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Trigger matching │  Async → Matching Engine
│ engine           │  Returns ranked provider list
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Notify matched   │  Push + email + SMS per provider preferences
│ providers        │  Include: job summary, location (area, not exact), dates
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Collect bids     │  24-hour bid window (configurable)
│ (bid_window)     │  Providers see job details, submit price + timeline
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Customer selects │  Bid comparison view
│ provider         │  Confirm → create escrow → schedule job
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Job execution    │  Provider marks: in_progress → completed
│                  │  Customer confirms: approved → payment released
│                  │  OR: disputed → operator review
└─────────────────┘
```

**Request States:**

```
open → matching → bidding → awarded → scheduled → in_progress → completed → closed
                                                       │
                                                       ├→ disputed → resolved → closed
                                                       └→ cancelled (by either party)
```

### 2.2 Matching Engine

The matching engine is the marketplace's core algorithm. It determines which providers see which jobs.

**Filter Pipeline (eliminates non-candidates):**

| Stage | Filter | Implementation |
|---|---|---|
| 1. Service type | Provider offers requested service category | B-tree index on provider_services.category_id |
| 2. Location | Provider service area covers job location | PostGIS: `ST_DWithin(provider.service_area, request.location, provider.radius)` |
| 3. Availability | Provider has capacity on requested dates | Calendar intersection query (provider_availability - active_jobs) |
| 4. Verification | Provider is verified and active (not suspended) | Status check: `providers.verification_status = 'verified' AND providers.is_active = true` |
| 5. Capacity | Provider below max concurrent job limit | Count active jobs < provider.max_concurrent |

**Ranking Algorithm (orders remaining candidates):**

```
composite_score = (
    0.35 × rating_score +        # Weighted composite rating (0-1 normalized)
    0.25 × completion_rate +     # % of accepted jobs completed (0-1)
    0.20 × response_time_score + # Inverse of avg time to first bid (faster = higher)
    0.15 × tier_bonus +          # Elite: 1.0, Preferred: 0.7, Standard: 0.4
    0.05 × recency_score         # Days since last completed job (recent = higher)
)
```

**Why these weights:**
- Rating (0.35): Strongest predictor of customer satisfaction. Providers with 4.5+ ratings have 73% repeat booking rates vs. 31% for providers below 4.0.
- Completion rate (0.25): Reliability matters. A high-rated provider who cancels 20% of jobs is worse than a solid 4.3 who always shows up.
- Response time (0.20): Fast bidders convert at 2.4x the rate of slow bidders. Customers often select the first qualified bid.
- Tier (0.15): Rewards sustained excellence. Elite providers earned their placement through consistent performance.
- Recency (0.05): Small factor to keep active providers visible and detect providers who may have gone inactive.

### 2.3 Payment Service

Built on Stripe Connect in platform/marketplace mode. The platform is the merchant of record.

```
Customer selects bid
        │
        ▼
┌─────────────────────────────┐
│ Create PaymentIntent         │
│ + Transfer (Stripe Connect)  │
│                              │
│ Amount: bid_price            │
│ + customer_fee (5%)          │
│ Application fee:             │
│   platform_fee (15%) +       │
│   customer_fee (5%)          │
│ Transfer to: provider's      │
│   connected account          │
│ Capture: manual (escrow)     │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Payment authorized           │
│ (funds held, not captured)   │
│                              │
│ Status: escrow_held          │
│ Hold duration: up to 7 days  │
│ past scheduled completion    │
└──────────────┬──────────────┘
               │
        ┌──────┴──────┐
        │             │
   Job completed   Dispute filed
        │             │
        ▼             ▼
┌──────────────┐ ┌──────────────────┐
│ Capture       │ │ Hold maintained   │
│ payment       │ │ pending operator  │
│               │ │ resolution        │
│ Provider      │ │                   │
│ payout in     │ │ Resolution:       │
│ 3-5 days      │ │ - Full capture    │
│               │ │ - Partial refund  │
│ Platform fee  │ │ - Full refund     │
│ retained      │ │ - Cancel hold     │
└──────────────┘ └──────────────────┘
```

**Key payment design decisions:**
- Manual capture (escrow) because customers need assurance that payment only processes when work is complete
- 7-day hold extension past completion date handles scheduling delays without requiring reauthorization
- Platform absorbs Stripe processing fees (2.9% + $0.30) to simplify provider earnings display
- Provider payouts on T+3-5 schedule via Stripe automated payouts (vs. T+30-60 with the old manual process)

### 2.4 Verification Service

Manages the provider trust pipeline from application through ongoing compliance.

```
┌─────────────────────────────────────────────────────────────────┐
│                    VERIFICATION PIPELINE                         │
│                                                                  │
│  ┌──────────────┐                                                │
│  │ Document      │  Provider uploads: ID, license, insurance     │
│  │ Collection    │  Stored in Supabase Storage (encrypted)       │
│  └──────┬───────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐     │
│  │ Identity +    │  │ License      │  │ Insurance          │     │
│  │ Background    │  │ Validation   │  │ Validation         │     │
│  │ (Checkr)      │  │              │  │                    │     │
│  │               │  │ State API    │  │ ACORD form parse   │     │
│  │ - Identity    │  │ lookup where │  │ - GL coverage ≥    │     │
│  │   verified    │  │ available    │  │   $1M              │     │
│  │ - No relevant │  │              │  │ - Workers comp     │     │
│  │   criminal    │  │ Manual       │  │   (if employees)   │     │
│  │   history     │  │ verification │  │ - Expiration date  │     │
│  │               │  │ for states   │  │   > 30 days out    │     │
│  │ Webhook:      │  │ without APIs │  │                    │     │
│  │ ~24-48 hours  │  │              │  │ Automated:         │     │
│  │               │  │ ~1-24 hours  │  │ < 1 minute         │     │
│  └──────┬───────┘  └──────┬───────┘  └────────┬───────────┘     │
│         │                  │                    │                 │
│         └──────────────────┼────────────────────┘                 │
│                            │                                     │
│                   All pass? │                                     │
│                  ┌─────────┴──────────┐                          │
│                  │                    │                           │
│                 Yes                  No                           │
│                  │                    │                           │
│                  ▼                    ▼                           │
│         ┌──────────────┐    ┌──────────────────┐                │
│         │ Operator      │    │ Rejection email   │                │
│         │ Review Queue  │    │ with specific     │                │
│         │               │    │ failure reasons    │                │
│         │ Manual checks:│    │ + resubmit link   │                │
│         │ - Portfolio   │    └──────────────────┘                │
│         │ - Phone screen│                                        │
│         │ - References  │                                        │
│         └──────┬───────┘                                        │
│                │                                                 │
│           Approved                                               │
│                │                                                 │
│                ▼                                                 │
│        ┌──────────────┐                                         │
│        │ Provider      │                                         │
│        │ activated     │                                         │
│        │ (Standard     │                                         │
│        │  Tier)        │                                         │
│        └──────────────┘                                         │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                  ONGOING COMPLIANCE                              │
│                                                                  │
│  Daily cron job scans for expiring credentials:                  │
│                                                                  │
│  30 days before expiry → Email reminder                          │
│  14 days before expiry → Email + SMS + in-app alert              │
│   7 days before expiry → Email + SMS + in-app + operator alert   │
│   0 days (expired)     → 14-day grace period starts              │
│  14 days past expiry   → Auto-suspend (no new jobs, active jobs  │
│                          can complete)                            │
│                                                                  │
│  Provider uploads new document → Re-verification pipeline        │
│  → Auto-reactivate if all checks pass                            │
└─────────────────────────────────────────────────────────────────┘
```

### 2.5 Review Service

Manages the rating and review lifecycle with anti-gaming protections.

**Composite Rating Calculation:**

```
composite_rating = (
    0.50 × quality_score +         # Workmanship and outcome
    0.30 × timeliness_score +      # On-time arrival and completion
    0.20 × communication_score     # Responsiveness and professionalism
)
```

**Anti-Gaming Protections:**
- Double-blind reviews: neither party sees the other's review until both have submitted (or 7-day window expires)
- Minimum 5 reviews before composite rating is displayed publicly (prevents gaming with fake early reviews)
- Operator can flag and investigate suspicious review patterns (e.g., multiple 5-star reviews from accounts created the same week)
- Providers cannot see which specific customer left which rating (only aggregate scores)
- Review editing window: 48 hours, then locked

**Tier Impact:**
- Composite rating directly feeds into tier calculations
- Rating drops below tier threshold trigger a 30-day probation (provider keeps tier but gets a warning)
- If rating doesn't recover within 30 days, tier is downgraded
- Tier upgrades are evaluated monthly based on trailing 90-day performance

---

## 3. Data Flow: Complete Job Lifecycle

```
1. CUSTOMER POSTS REQUEST
   Customer App → API → Request Service → DB (status: open)
                                        → Matching Engine (async)

2. MATCHING
   Matching Engine → PostGIS filter → Composite ranking → Redis (matched list)
                  → Notification Service → Push/Email/SMS to top 10 providers

3. PROVIDERS BID
   Provider App → API → Bid Service → DB (new bid)
                                    → WebSocket → Customer App (real-time bid notification)

4. CUSTOMER SELECTS
   Customer App → API → Request Service → DB (status: awarded)
                     → Payment Service → Stripe Connect (escrow hold)
                     → Notification Service → Provider (you've been selected)

5. JOB EXECUTION
   Provider App → API → Request Service → DB (status: in_progress → completed)
                     → WebSocket → Customer App (status update)

6. PAYMENT RELEASE
   Customer App → API (confirm completion) → Payment Service → Stripe (capture)
                                           → DB (payment status: captured)
                                           → Provider payout scheduled (T+3-5)

7. REVIEW
   Customer App → API → Review Service → DB (review stored)
   Provider App → API → Review Service → DB (review stored)
                                       → Rating recalculation
                                       → Tier evaluation (if threshold crossed)
```

---

## 4. Infrastructure

### 4.1 Deployment Architecture

| Component | Service | Rationale |
|---|---|---|
| Frontend (3 portals) | Vercel | Next.js native hosting, edge CDN, preview deployments per PR |
| API server | Railway | FastAPI containers with auto-scaling, managed PostgreSQL connection pooling |
| Database | Supabase (PostgreSQL + PostGIS) | Managed Postgres with built-in auth, RLS, realtime, storage, and PostGIS |
| Task queue | Railway (Celery workers) | Async tasks: matching, notifications, verification webhooks, payment processing |
| Cache / queue broker | Redis (Upstash) | Serverless Redis for Celery broker, rate limiting, session cache |
| File storage | Supabase Storage | Integrated with auth and RLS; stores documents, photos, certificates |
| CDN | Vercel Edge Network | Static assets and ISR pages served from edge |

### 4.2 Environment Strategy

| Environment | Purpose | Data |
|---|---|---|
| Local | Developer workstations | Docker Compose with local Postgres + PostGIS + Redis |
| Staging | QA and demo | Supabase project (staging), Railway staging service, Stripe test mode |
| Production | Live marketplace | Supabase project (prod), Railway production service, Stripe live mode |

### 4.3 Security Architecture

**Authentication:**
- Supabase Auth issues JWTs with custom claims (role, tenant)
- Three roles: customer, provider, operator
- JWT includes: user_id, role, email, metadata
- Token refresh: 1-hour access token, 7-day refresh token

**Authorization (RLS):**

```sql
-- Customers can only see their own requests
CREATE POLICY customer_requests ON service_requests
    FOR SELECT USING (customer_id = auth.uid());

-- Providers can only see requests they've been matched to
CREATE POLICY provider_matched_requests ON service_requests
    FOR SELECT USING (
        id IN (SELECT request_id FROM matched_providers WHERE provider_id = auth.uid())
    );

-- Providers can only see their own bids
CREATE POLICY provider_own_bids ON bids
    FOR SELECT USING (provider_id = auth.uid());

-- Customers can see all bids on their requests (but not other customers' requests)
CREATE POLICY customer_request_bids ON bids
    FOR SELECT USING (
        request_id IN (SELECT id FROM service_requests WHERE customer_id = auth.uid())
    );

-- Operators can see everything
CREATE POLICY operator_all ON service_requests
    FOR ALL USING (auth.jwt() ->> 'role' = 'operator');
```

**Data Protection:**
- Provider documents (licenses, insurance, ID) encrypted at rest in Supabase Storage
- PII access logged in audit trail
- Customer payment data never touches our servers (Stripe handles PCI compliance)
- Background check results stored as pass/fail status only (not detailed report)

---

## 5. Performance Optimization

### 5.1 Geospatial Queries

PostGIS performance is critical for matching. Every service request triggers a radius search across potentially thousands of providers.

**Index Strategy:**

```sql
-- Spatial index on provider service areas (GIST)
CREATE INDEX idx_providers_location ON providers USING GIST (service_location);

-- Combined index for the most common matching query
-- (service type + location + active status)
CREATE INDEX idx_provider_matching ON provider_services (category_id)
    INCLUDE (provider_id)
    WHERE is_active = true;
```

**Query Optimization:**
- `ST_DWithin` with geography type for accurate distance calculations
- Provider locations stored as PostGIS POINT geometry
- Service areas pre-calculated as radius from provider's base location
- Materialized view refreshed hourly for provider availability (avoids complex joins on every match)

### 5.2 Real-Time Updates

WebSocket connections via Supabase Realtime for:
- New bid notifications (customer sees bids appear in real time)
- Job status changes (both parties see status transitions)
- Chat messages (in-app messaging between customer and provider)

**Channel Strategy:**
- `request:{request_id}` - All updates for a specific service request
- `provider:{provider_id}` - Job matches, bid responses, earnings updates
- `operator:dashboard` - Network-wide metrics and alerts

### 5.3 Caching Strategy

| Data | Cache Location | TTL | Invalidation |
|---|---|---|---|
| Provider profiles (public) | Redis | 15 minutes | On profile update |
| Matching results | Redis | 5 minutes | On new provider signup or status change |
| Service categories | Redis | 24 hours | On operator configuration change |
| Marketplace health metrics | Redis | 5 minutes | On scheduled recalculation |
| Provider composite ratings | Materialized view | 1 hour | Scheduled refresh |

---

## 6. Monitoring and Observability

### 6.1 Application Monitoring

| Tool | Purpose |
|---|---|
| Sentry | Error tracking, exception grouping, release tracking |
| Datadog APM | Request tracing, latency percentiles, database query performance |
| Supabase Dashboard | Database metrics, auth events, storage usage, realtime connections |
| Stripe Dashboard | Payment volume, failure rates, dispute rates, payout timing |

### 6.2 Key Alerts

| Alert | Condition | Severity | Action |
|---|---|---|---|
| Matching engine latency | p95 > 5 seconds | Warning | Investigate PostGIS query performance |
| Payment failure rate | > 5% in 1 hour | Critical | Check Stripe status, investigate failures |
| Bid coverage drop | < 60% of requests get 3+ bids (rolling 24h) | Warning | Check provider notification delivery, market supply |
| Provider verification backlog | > 20 applications pending > 48 hours | Warning | Alert operator team, consider temporary staffing |
| Credential expiration | > 10% of active providers have credentials expiring within 14 days | Warning | Trigger bulk reminder campaign |
| WebSocket connection spike | > 2x normal concurrent connections | Info | Monitor for potential abuse or traffic spike |

---

## 7. Technology Selection Rationale

| Component | Selected | Alternative Considered | Why Selected |
|---|---|---|---|
| Frontend | Next.js 14 | React SPA | SSR for SEO on provider profiles; shared component library across 3 portals; API routes for BFF pattern |
| API | FastAPI | Django REST Framework | Async native for real-time bidding; Pydantic validation; better performance for high-concurrency matching |
| Database | Supabase (PostgreSQL + PostGIS) | PlanetScale (MySQL) | PostGIS for geospatial queries; built-in auth + RLS + realtime + storage in one platform |
| Payments | Stripe Connect | Square, PayPal | Best marketplace/platform support; native split payments; escrow (manual capture); automated 1099s |
| Background checks | Checkr | GoodHire, Sterling | Best API/webhook integration; fast turnaround; good documentation |
| Notifications | SendGrid + Twilio + FCM | Courier, OneSignal | Proven at scale; separate best-of-breed services vs. unified platform with less reliability |
| Task queue | Celery + Redis | Temporal, AWS SQS | Team familiarity; sufficient for our scale; well-documented; easy local development |
| Geocoding | Google Maps Platform | Mapbox, HERE | Most accurate US address geocoding; good PostGIS integration patterns |
