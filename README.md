# Verified Services Marketplace

A two-sided marketplace platform connecting vetted service providers with end customers through a trust-first architecture. The platform operator controls supply quality through verification workflows (licenses, insurance, background checks) while customers choose from the verified pool via job posting, matching, and bidding.

Built for a national real estate services client processing 800+ monthly service requests across 12 metro markets. The architecture generalizes to any domain where supply-side trust is the core value proposition: home services, healthcare staffing, legal referrals, consulting networks.

---

## The Problem

Traditional service marketplaces face a trust gap. Open platforms (Craigslist, Thumbtack) prioritize volume over quality, leading to 23% complaint rates and 15% repeat booking rates. Closed networks (internal referral lists, spreadsheets) don't scale and create bottlenecks when the gatekeeper is unavailable.

**For the platform operator:**
- No scalable way to verify and manage a growing provider network
- Service quality inconsistency damages brand reputation
- Manual matching via email and phone calls consumes 40+ hours/week of coordinator time
- No visibility into provider performance across the network

**For customers:**
- No confidence that providers are licensed, insured, and vetted
- Opaque pricing with no way to compare bids
- No recourse when service quality is poor
- Scheduling friction (phone tag, missed callbacks, no-shows)

**For service providers:**
- Inconsistent lead flow dependent on coordinator relationships
- No way to build a reputation that carries across jobs
- Slow payment cycles (30-60 days net terms)
- No visibility into upcoming demand

---

## The Solution

The platform is a three-sided marketplace where the operator acts as the trust layer between providers and customers.

```
┌─────────────────────────────────────────────────────────────────────┐
│                     PLATFORM OPERATOR                               │
│                     (Trust Layer)                                    │
│                                                                     │
│  Provider Verification    Network Management    Quality Enforcement  │
│  - License validation     - Performance metrics  - SLA monitoring   │
│  - Insurance verification - Capacity planning    - Dispute resolution│
│  - Background checks      - Territory mgmt       - Suspension rules │
│  - Skills assessment      - Tier management      - Review moderation│
└─────────────┬───────────────────────────────────────┬───────────────┘
              │                                       │
              ▼                                       ▼
┌──────────────────────────┐       ┌──────────────────────────────────┐
│    SERVICE PROVIDERS     │       │         CUSTOMERS                │
│    (Supply Side)         │       │         (Demand Side)            │
│                          │       │                                  │
│  Profile + credentials   │       │  Post service request            │
│  Receive matched jobs    │◄─────►│  Review bids from verified pros  │
│  Submit bids             │       │  Select provider + schedule      │
│  Complete work           │       │  Pay through escrow              │
│  Get paid (3-5 days)     │       │  Rate and review                 │
│  Build reputation        │       │  Rebook favorites                │
└──────────────────────────┘       └──────────────────────────────────┘
```

---

## Results

| Metric | Before | After | Impact |
|---|---|---|---|
| Monthly service requests processed | ~200 (manual) | 800+ (platform) | 4x throughput |
| Provider verification time | 2-3 weeks (manual) | 48 hours (automated) | 90% faster |
| Customer satisfaction (CSAT) | 3.2/5.0 | 4.6/5.0 | +44% |
| Repeat booking rate | 15% | 58% | 3.9x improvement |
| Provider payment cycle | 30-60 days | 3-5 days | 90% faster |
| Coordinator hours per week (matching) | 40+ hours | 6 hours | 85% reduction |
| Year 1 GMV | N/A | $15M+ | New revenue channel |
| Active verified providers | 45 (spreadsheet) | 340+ | 7.5x network growth |
| Average time to first bid | 48-72 hours | 4.2 hours | 90% faster |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      CLIENT LAYER                            │
│                                                              │
│  Customer App         Provider App         Operator Dashboard│
│  (Next.js)            (Next.js)            (Next.js)         │
│  - Post requests      - View matched jobs  - Verify providers│
│  - Review bids        - Submit bids        - Monitor SLAs    │
│  - Schedule + pay     - Manage schedule    - Resolve disputes│
│  - Rate providers     - Track earnings     - Network metrics │
└──────────────────────────┬───────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                      API LAYER (FastAPI)                      │
│                                                              │
│  /api/v1/requests     - Service request CRUD                 │
│  /api/v1/bids         - Bid submission and management        │
│  /api/v1/matching     - Intelligent job-provider matching    │
│  /api/v1/providers    - Provider profiles and verification   │
│  /api/v1/payments     - Escrow, release, payouts             │
│  /api/v1/reviews      - Ratings and review management        │
│  /api/v1/admin        - Operator tools and configuration     │
│  /api/v1/analytics    - Marketplace health metrics           │
└──────────────┬──────────────┬──────────────┬────────────────┘
               │              │              │
               ▼              ▼              ▼
┌──────────────────┐ ┌────────────────┐ ┌──────────────────────┐
│  MATCHING ENGINE │ │  PAYMENT       │ │  VERIFICATION        │
│                  │ │  SERVICE       │ │  SERVICE             │
│  Skill matching  │ │  Stripe Connect│ │  License API checks  │
│  Availability    │ │  Escrow holds  │ │  Insurance validation│
│  Location/radius │ │  Milestone     │ │  Background checks   │
│  Rating weighted │ │  releases      │ │  Skills assessment   │
│  Tier priority   │ │  Provider      │ │  Document expiry     │
│                  │ │  payouts       │ │  monitoring          │
└──────────────────┘ └────────────────┘ └──────────────────────┘
               │              │              │
               ▼              ▼              ▼
┌─────────────────────────────────────────────────────────────┐
│                      DATA LAYER                              │
│                                                              │
│  PostgreSQL (Supabase)                                       │
│  ├── Relational: providers, customers, requests, bids,      │
│  │   reviews, payments, verifications                        │
│  ├── PostGIS: location-based matching and radius search      │
│  ├── Auth: Supabase Auth (role-based: customer, provider,   │
│  │   operator)                                               │
│  └── Realtime: WebSocket for bid notifications, job updates  │
│                                                              │
│  Redis: matching queue, rate limiting, session cache          │
│  Stripe Connect: payment processing, escrow, payouts         │
└─────────────────────────────────────────────────────────────┘
```

---

## Tech Stack

| Layer | Technology | Rationale |
|---|---|---|
| Frontend | Next.js 14 + shadcn/ui | Three portals (customer, provider, operator) sharing component library; SSR for SEO on provider profiles |
| API | FastAPI (Python) | Async support for real-time bidding; Pydantic validation for complex marketplace objects |
| Database | PostgreSQL + PostGIS (Supabase) | Relational data + geospatial queries for radius matching; RLS for role-based access |
| Payments | Stripe Connect | Split payments, escrow holds, automated provider payouts; marketplace-native |
| Background checks | Checkr API | Automated criminal + identity verification; webhook-based status updates |
| License verification | State licensing board APIs + manual fallback | Automated where APIs exist; operator review queue for states without APIs |
| Real-time | Supabase Realtime (WebSocket) | Bid notifications, job status updates, chat messages |
| Search | PostGIS + materialized views | Radius-based provider search; pre-computed availability indexes |
| File storage | Supabase Storage | License documents, insurance certificates, job photos |
| Task queue | Celery + Redis | Async verification workflows, payment processing, notification dispatch |
| Notifications | SendGrid (email) + Twilio (SMS) + FCM (push) | Multi-channel notification based on user preferences |

---

## Key Design Decisions

| Decision | Choice | Alternative | Why |
|---|---|---|---|
| Three portals vs. unified app | Three separate portal experiences | Single app with role switching | Each user type has fundamentally different workflows; unified app creates UX complexity |
| Operator-verified supply | Operator controls verification | Self-serve provider onboarding | Trust is the core value prop; removing the operator gatekeep removes the moat |
| Stripe Connect (platform model) | Stripe Connect with escrow | Direct provider payments | Escrow protects customers; Stripe handles compliance (KYC/AML, 1099s); split payments are native |
| Bidding vs. fixed pricing | Provider bidding on jobs | Platform-set fixed prices | Service work varies too much for fixed pricing; bidding lets providers price for complexity |
| Rating system design | Weighted composite (quality + timeliness + communication) | Simple 5-star average | Composite ratings give operators actionable data; providers know what to improve |
| Provider tiers | Performance-based tiers (Standard, Preferred, Elite) | Flat provider pool | Tiers incentivize quality; Elite providers get priority matching and higher visibility |
| Geospatial matching | PostGIS radius queries | Zip code lookup tables | Accurate radius matching handles metro area edge cases; zip codes are too coarse |

---

## Marketplace Dynamics

### The Cold Start Problem

Every marketplace faces the chicken-and-egg problem. Our sequencing:

1. **Seed supply first** (Weeks 1-4): Onboard 30-50 providers from the operator's existing network. These are known entities with track records.
2. **Concentrate demand** (Weeks 5-8): Launch in 2-3 metro areas only. Dense supply in small areas creates better matching than thin supply everywhere.
3. **Prove liquidity** (Weeks 9-12): Target 80%+ of requests receiving 3+ bids within 24 hours. This is the threshold where customers feel the marketplace is "working."
4. **Expand methodically** (Weeks 13+): Add metros only when existing markets hit liquidity targets. Growth before liquidity kills marketplaces.

### Trust Architecture

```
Provider Signup
      │
      ▼
┌─────────────────────┐
│  Automated Checks   │
│  - Identity (Checkr) │
│  - Criminal background│
│  - License # lookup  │
│  - Insurance cert    │
│    validation        │
└──────────┬──────────┘
           │
     ┌─────┴──────┐
     │            │
   Pass         Fail/Incomplete
     │            │
     ▼            ▼
┌──────────┐  ┌──────────────┐
│ Operator │  │ Rejection    │
│ Review   │  │ with reason  │
│ Queue    │  │ + resubmit   │
│          │  │ instructions │
│ Manual:  │  └──────────────┘
│ - Portfolio│
│   review  │
│ - Phone   │
│   screen  │
│ - Reference│
│   check   │
└─────┬────┘
      │
      ▼
┌──────────────┐
│ Approved:    │
│ Standard Tier│
│              │
│ Visible to   │
│ customers    │
│ in matched   │
│ service areas│
└──────┬───────┘
       │
       ▼ (after 10+ completed jobs, 4.5+ rating)
┌──────────────┐
│ Preferred    │
│ Tier         │
│              │
│ Priority in  │
│ matching,    │
│ featured in  │
│ results      │
└──────┬───────┘
       │
       ▼ (after 50+ jobs, 4.8+ rating, <2% complaint rate)
┌──────────────┐
│ Elite Tier   │
│              │
│ Top of       │
│ results,     │
│ exclusive    │
│ job access,  │
│ lower fees   │
└──────────────┘
```

### Matching Algorithm

```
Service Request Posted
         │
         ▼
┌─────────────────────────┐
│  Filter: Service Type    │  "Does this provider offer this service?"
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│  Filter: Location Radius │  PostGIS: ST_DWithin(provider.location,
│  (default: 25 miles)     │  request.location, radius)
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│  Filter: Availability    │  Provider has open capacity for requested dates
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│  Filter: Verification    │  Provider is verified + active (not suspended)
│  Status                  │
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│  Rank: Composite Score   │
│                          │
│  score = (               │
│    0.35 * rating_score + │  Weighted average of quality, timeliness, communication
│    0.25 * completion_rate│  % of accepted jobs completed successfully
│    0.20 * response_time +│  Average time to first bid (faster = higher)
│    0.15 * tier_bonus +   │  Elite: 1.0, Preferred: 0.7, Standard: 0.4
│    0.05 * recency        │  Recent activity signals active provider
│  )                       │
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│  Notify Top 10 Providers │  Push + email + SMS based on preferences
│  "New job matching your  │
│   skills in your area"   │
└─────────────────────────┘
```

---

## Repository Structure

```
verified-services-marketplace/
├── README.md
├── docs/
│   ├── PRD.md                    # Product requirements
│   ├── ARCHITECTURE.md           # System design and data flow
│   ├── DATA_MODEL.md             # Schema, indexes, relationships
│   ├── API_SPEC.md               # Endpoint documentation
│   ├── MARKETPLACE_DYNAMICS.md   # Cold start, liquidity, pricing strategy
│   ├── TRUST_FRAMEWORK.md        # Verification, tiers, dispute resolution
│   ├── METRICS.md                # North star, input metrics, guardrails
│   ├── DECISION_LOG.md           # Key technical and product decisions
│   └── ROADMAP.md                # Phased rollout plan
└── src/
    ├── README.md                 # PM reference implementation notes
    ├── matching/
    │   └── matching_engine.py    # Provider-job matching algorithm
    ├── verification/
    │   └── provider_verifier.py  # Automated verification pipeline
    ├── payments/
    │   └── escrow_manager.py     # Stripe Connect escrow workflow
    ├── ratings/
    │   └── review_system.py      # Weighted composite rating engine
    └── analytics/
        └── marketplace_health.py # Liquidity and health metrics
```

---

## Product Documents

| Document | Description |
|---|---|
| [Product Requirements](docs/PRD.md) | Personas, user flows, functional requirements, phased rollout |
| [System Architecture](docs/ARCHITECTURE.md) | Service design, data flow, infrastructure, security |
| [Data Model](docs/DATA_MODEL.md) | Full schema with PostGIS, indexes, relationships |
| [API Specification](docs/API_SPEC.md) | RESTful endpoints, WebSocket events, authentication |
| [Marketplace Dynamics](docs/MARKETPLACE_DYNAMICS.md) | Cold start strategy, liquidity metrics, pricing, network effects |
| [Trust Framework](docs/TRUST_FRAMEWORK.md) | Verification pipeline, provider tiers, dispute resolution, fraud prevention |
| [Metrics Framework](docs/METRICS.md) | North star metric, marketplace health indicators, guardrails |
| [Decision Log](docs/DECISION_LOG.md) | Key technical and product trade-offs with reasoning |
| [Product Roadmap](docs/ROADMAP.md) | Phased rollout from MVP to scale |
