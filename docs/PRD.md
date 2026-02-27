# Product Requirements Document: Verified Services Marketplace

**Author:** Jacob George, Principal Product Manager
**Last Updated:** January 2025
**Status:** Approved

---

## 1. Overview

### 1.1 Product Vision

A marketplace platform where the operator controls supply quality through verification workflows while customers choose from a trusted, pre-vetted provider pool. The platform eliminates the trust gap that plagues open marketplaces and the scalability bottleneck that limits closed referral networks.

### 1.2 Business Context

The client operates a national services network across 12 metro markets. Before the platform:

- Provider management lived in spreadsheets and email threads
- A team of 6 coordinators manually matched service requests to providers via phone calls
- Verification was ad hoc - some providers had current documentation, many didn't
- Customers had no visibility into provider qualifications or track records
- Payment terms were net-30 to net-60, causing provider cash flow issues and churn
- No centralized data on service quality, completion rates, or customer satisfaction

The business needed a platform that could scale the network from ~200 manual requests/month to 800+ while maintaining (and improving) service quality.

### 1.3 Success Criteria

| Metric | Target | Rationale |
|---|---|---|
| Monthly GMV | $1.25M by Month 12 | Path to $15M+ annual run rate |
| Request-to-bid time | < 6 hours (median) | Customers expect same-day response |
| Bid coverage | 80%+ of requests get 3+ bids | Marketplace feels "alive" and competitive |
| Repeat booking rate | > 50% | Indicates trust and satisfaction |
| Provider verification time | < 48 hours | Fast onboarding keeps supply pipeline flowing |
| Customer CSAT | > 4.5/5.0 | Trust premium over open marketplaces |
| Provider NPS | > 40 | Providers must want to stay on the platform |

---

## 2. Personas

### 2.1 Customer (Demand Side)

**"Sarah" - Homeowner / End Customer**
- Needs a service performed (repair, renovation, maintenance, inspection)
- Wants confidence that the provider is licensed, insured, and vetted
- Values transparency: wants to compare bids, see reviews, understand pricing
- Expects modern digital experience (not phone calls and voicemails)
- Will pay a reasonable premium for verified, quality-assured service

**Key Jobs to Be Done:**
1. Find a qualified provider I can trust without doing my own research
2. Compare options and pricing before committing
3. Know the provider will show up on time and do quality work
4. Have recourse if something goes wrong
5. Easily rebook providers I've had good experiences with

### 2.2 Service Provider (Supply Side)

**"Mike" - Licensed Contractor / Service Provider**
- Independent or small business (1-10 employees)
- Licensed and insured but has no way to signal this to customers
- Wants consistent lead flow without paying for advertising
- Frustrated by slow payment cycles and price-shopping customers
- Willing to be vetted if it means better jobs and less competition from unqualified providers

**Key Jobs to Be Done:**
1. Get a steady stream of qualified leads in my service area
2. Get paid quickly and reliably
3. Build a reputation that earns me better jobs over time
4. Know what jobs are coming so I can plan my schedule
5. Spend time doing work, not chasing leads

### 2.3 Platform Operator (Trust Layer)

**"Lisa" - Network Manager / Operations Lead**
- Responsible for maintaining service quality across the network
- Manages provider onboarding, verification, and performance
- Handles escalations and disputes between customers and providers
- Needs data to make decisions about network expansion and provider management
- Currently drowning in manual coordination work

**Key Jobs to Be Done:**
1. Verify providers efficiently without bottlenecking onboarding
2. Monitor service quality across the entire network in real time
3. Identify and address problems before they become customer complaints
4. Scale the network to new markets without proportionally scaling headcount
5. Generate reporting for leadership on marketplace health and growth

---

## 3. User Flows

### 3.1 Customer Flow: Post Request → Select Provider → Complete Job

```
Customer logs in
      │
      ▼
Posts service request
├── Service category (plumbing, electrical, HVAC, etc.)
├── Description of work needed
├── Location (auto-detected or entered)
├── Preferred dates/times
├── Photos (optional)
└── Budget range (optional)
      │
      ▼
System matches request to qualified providers
├── Filter: service type, location radius, availability, verification status
├── Rank: composite score (rating, completion rate, response time, tier)
└── Notify top 10 matched providers
      │
      ▼
Providers submit bids (within 24-hour window)
├── Proposed price
├── Estimated timeline
├── Scope of work description
├── Provider profile visible (rating, reviews, credentials, tier badge)
      │
      ▼
Customer reviews bids
├── Compare price, timeline, provider ratings side-by-side
├── View provider profiles, past reviews, verification badges
├── Message providers with questions (in-app chat)
      │
      ▼
Customer selects provider and confirms
├── Escrow payment created (Stripe Connect)
├── Both parties receive confirmation with details
├── Calendar event created with scheduled date/time
      │
      ▼
Provider completes work
├── Provider marks job as complete
├── Customer confirms completion
├── Customer can request revisions if needed
      │
      ▼
Payment released from escrow
├── Platform fee deducted (15%)
├── Provider receives payout (3-5 business days)
      │
      ▼
Customer rates and reviews provider
├── Quality (1-5)
├── Timeliness (1-5)
├── Communication (1-5)
├── Written review (optional)
└── "Would you book again?" (yes/no)
```

### 3.2 Provider Flow: Onboarding → Verification → Active

```
Provider signs up
├── Basic profile (name, business name, contact)
├── Service categories offered
├── Service area (address + radius)
├── Availability schedule
      │
      ▼
Document upload
├── Government ID
├── Business license
├── Trade/specialty licenses
├── Insurance certificate (GL + Workers Comp)
├── Portfolio photos (optional)
      │
      ▼
Automated verification (parallel)
├── Identity check (Checkr API)
├── Criminal background check (Checkr API)
├── License number validation (state licensing board API where available)
├── Insurance certificate validation (ACORD form parsing)
      │
      ▼
┌─────────────────────────┐
│  All automated checks    │
│  pass?                   │
├──────────┬──────────────┤
│  Yes     │  No          │
│          │              │
│  ▼       │  ▼           │
│ Operator │ Rejection    │
│ review   │ with reason  │
│ queue    │ + resubmit   │
│          │ option       │
└──────────┴──────────────┘
      │
      ▼
Operator manual review
├── Portfolio/work quality assessment
├── Phone screen (15 min)
├── Reference check (1-2 past clients)
      │
      ▼
Approved → Standard Tier
├── Profile goes live
├── Receives matched job notifications
├── Can submit bids
      │
      ▼
Performance-based tier progression
├── 10+ jobs, 4.5+ rating → Preferred Tier (priority matching, featured placement)
├── 50+ jobs, 4.8+ rating, <2% complaints → Elite Tier (exclusive access, lower fees)
```

### 3.3 Operator Flow: Daily Operations

```
Morning dashboard review
├── New provider applications pending review
├── Active disputes requiring resolution
├── SLA alerts (providers with declining metrics)
├── Network health: liquidity by market, fill rate, avg response time
      │
      ▼
Provider management
├── Review and approve/reject new applications
├── Monitor expiring credentials (licenses, insurance)
├── Handle tier promotions/demotions based on performance
├── Investigate flagged reviews or complaints
      │
      ▼
Dispute resolution
├── Review dispute details (customer complaint, provider response)
├── View job history, messages, photos
├── Make ruling: refund, partial refund, dismiss, suspend provider
├── Communicate decision to both parties
      │
      ▼
Network expansion
├── Identify markets with high demand / low supply
├── Recruit providers in underserved areas
├── Adjust matching radius for thin markets
├── Track onboarding funnel conversion
```

---

## 4. Functional Requirements

### 4.1 Customer Portal

| ID | Requirement | Priority |
|---|---|---|
| C-01 | Post a service request with category, description, location, dates, photos | P0 |
| C-02 | View matched provider bids with price, timeline, provider profile | P0 |
| C-03 | Compare bids side-by-side (price, rating, reviews, credentials) | P0 |
| C-04 | Select a provider and confirm booking with escrow payment | P0 |
| C-05 | In-app messaging with providers (pre and post booking) | P0 |
| C-06 | Confirm job completion and release payment | P0 |
| C-07 | Rate provider on quality, timeliness, communication (1-5 each) | P0 |
| C-08 | View past bookings and rebook favorite providers | P1 |
| C-09 | Save draft service requests | P1 |
| C-10 | Receive push/email/SMS notifications for bid updates, scheduling, completion | P0 |
| C-11 | File a dispute with description and supporting photos | P0 |
| C-12 | View provider verification badges (licensed, insured, background checked) | P0 |

### 4.2 Provider Portal

| ID | Requirement | Priority |
|---|---|---|
| P-01 | Create and manage profile (services, area, availability, portfolio) | P0 |
| P-02 | Upload verification documents (ID, licenses, insurance) | P0 |
| P-03 | Receive notifications for matched job opportunities | P0 |
| P-04 | View job details and submit bids (price, timeline, scope) | P0 |
| P-05 | Accept/decline job after customer selects them | P0 |
| P-06 | Mark jobs as in-progress and complete | P0 |
| P-07 | View earnings dashboard (pending, available, paid out) | P0 |
| P-08 | Manage availability calendar (block dates, set recurring hours) | P1 |
| P-09 | View own ratings and reviews | P0 |
| P-10 | Respond to customer reviews | P1 |
| P-11 | View tier status and progress toward next tier | P1 |
| P-12 | Receive alerts for expiring credentials (30, 14, 7 days before) | P0 |

### 4.3 Operator Dashboard

| ID | Requirement | Priority |
|---|---|---|
| O-01 | Review and approve/reject provider applications | P0 |
| O-02 | View verification status and documents for any provider | P0 |
| O-03 | Monitor marketplace health metrics (liquidity, fill rate, CSAT, response time) | P0 |
| O-04 | Manage disputes (view details, make rulings, communicate decisions) | P0 |
| O-05 | Configure matching parameters (radius, tier weights, bid window duration) | P1 |
| O-06 | Suspend or deactivate providers with notes | P0 |
| O-07 | View and manage expiring credentials across all providers | P0 |
| O-08 | Generate reports (GMV, provider performance, market-level metrics) | P1 |
| O-09 | Configure service categories and subcategories | P1 |
| O-10 | Set and adjust platform fee percentage | P1 |
| O-11 | Manage notification templates (email, SMS, push) | P2 |
| O-12 | View audit log of all operator actions | P0 |

### 4.4 Matching Engine

| ID | Requirement | Priority |
|---|---|---|
| M-01 | Filter providers by service type, location radius, availability, verification status | P0 |
| M-02 | Rank matched providers by composite score (rating, completion rate, response time, tier) | P0 |
| M-03 | Notify top N matched providers (configurable, default 10) | P0 |
| M-04 | Respect provider capacity limits (max concurrent jobs) | P1 |
| M-05 | Support configurable matching radius per market (dense vs. rural) | P1 |
| M-06 | Re-match if insufficient bids received within bid window | P1 |

### 4.5 Payments

| ID | Requirement | Priority |
|---|---|---|
| PAY-01 | Create escrow hold when customer confirms booking (Stripe Connect) | P0 |
| PAY-02 | Release payment to provider upon customer confirmation of completion | P0 |
| PAY-03 | Deduct platform fee (configurable, default 15%) before provider payout | P0 |
| PAY-04 | Process provider payouts within 3-5 business days | P0 |
| PAY-05 | Support milestone payments for multi-phase jobs | P1 |
| PAY-06 | Handle refunds (full or partial) for disputed jobs | P0 |
| PAY-07 | Generate 1099 tax documents for providers (annual) | P1 |
| PAY-08 | Provider earnings dashboard (pending, available, paid, lifetime) | P0 |

### 4.6 Reviews and Ratings

| ID | Requirement | Priority |
|---|---|---|
| R-01 | Customer rates provider on quality, timeliness, communication (1-5 each) | P0 |
| R-02 | Calculate weighted composite rating (quality 50%, timeliness 30%, communication 20%) | P0 |
| R-03 | Display composite rating and individual dimension scores on provider profile | P0 |
| R-04 | Provider can respond to reviews (public response) | P1 |
| R-05 | Operator can moderate reviews (hide fraudulent/abusive reviews with reason) | P0 |
| R-06 | Reviews visible only after both parties have submitted (prevent retaliation) | P0 |
| R-07 | Minimum 5 reviews before composite rating is displayed publicly | P0 |

### 4.7 Verification

| ID | Requirement | Priority |
|---|---|---|
| V-01 | Automated identity and background check via Checkr API | P0 |
| V-02 | License number validation against state licensing board APIs | P0 |
| V-03 | Insurance certificate upload and ACORD form field extraction | P0 |
| V-04 | Operator manual review queue for applications that pass automated checks | P0 |
| V-05 | Credential expiration monitoring with automated alerts (30/14/7 days) | P0 |
| V-06 | Auto-suspend providers with expired credentials (grace period: 14 days) | P0 |
| V-07 | Re-verification workflow for expired or updated documents | P1 |
| V-08 | Verification status badges visible to customers (licensed, insured, background checked) | P0 |

---

## 5. Non-Functional Requirements

| Category | Requirement | Target |
|---|---|---|
| Performance | Page load time | < 2 seconds (p95) |
| Performance | Matching engine execution | < 3 seconds per request |
| Performance | Search results (provider lookup) | < 1 second |
| Availability | Platform uptime | 99.5% (excludes scheduled maintenance) |
| Scalability | Concurrent service requests | 500+ active at any time |
| Scalability | Provider network size | 1,000+ verified providers |
| Security | Payment data | PCI DSS compliant (via Stripe) |
| Security | Personal data | SOC 2 Type II (target: Year 2) |
| Security | Role-based access | Customers cannot see other customers' data; providers cannot see other providers' bids |
| Data | Backup frequency | Daily automated backups, 30-day retention |
| Data | Data export | Operator can export all data in CSV format |

---

## 6. Out of Scope (V1)

| Feature | Reason | Revisit When |
|---|---|---|
| Provider mobile app (native) | Progressive web app sufficient for V1; native adds 3 months | V1 adoption data shows >30% mobile provider usage |
| Real-time job tracking (GPS) | Complex to build, unclear if customers value it for service work | Customer research indicates demand |
| Automated pricing recommendations | Insufficient data in V1; need 6+ months of bid history | 10K+ completed jobs in the dataset |
| Multi-language support | All V1 markets are English-speaking | Expansion to non-English markets |
| Provider financing / cash advances | Regulatory complexity; need lending partner | Provider NPS feedback identifies payment timing as top issue |
| Customer subscription model | Unclear pricing model; start with per-transaction fees | Repeat booking rate exceeds 60% |
| AI-powered job description enhancement | Nice-to-have; manual descriptions work | Customer feedback indicates poor bid quality due to vague descriptions |

---

## 7. Appendix

### 7.1 Service Categories (V1)

| Category | Subcategories |
|---|---|
| Plumbing | Repair, installation, inspection, emergency |
| Electrical | Repair, installation, panel upgrade, inspection |
| HVAC | Repair, installation, maintenance, inspection |
| General Contracting | Renovation, remodel, addition, repair |
| Painting | Interior, exterior, cabinet, deck/fence |
| Roofing | Repair, replacement, inspection, gutter |
| Landscaping | Design, maintenance, irrigation, hardscape |
| Cleaning | Deep clean, move-in/out, recurring, post-construction |
| Flooring | Hardwood, tile, carpet, LVP, repair |
| Pest Control | Inspection, treatment, prevention, wildlife removal |

### 7.2 Provider Tier Criteria

| Tier | Requirements | Benefits |
|---|---|---|
| Standard | Verified (all checks passed) | Access to matched jobs, standard bid placement |
| Preferred | 10+ completed jobs, 4.5+ composite rating, < 5% complaint rate | Priority in matching results, "Preferred" badge, featured in category pages |
| Elite | 50+ completed jobs, 4.8+ composite rating, < 2% complaint rate | Top placement, exclusive job access (24-hour head start), reduced platform fee (12% vs. 15%), "Elite" badge |

### 7.3 Platform Fee Structure

| Transaction Component | Fee |
|---|---|
| Customer service fee | 5% of job total (added to customer invoice) |
| Provider platform fee (Standard/Preferred) | 15% of job total (deducted from payout) |
| Provider platform fee (Elite) | 12% of job total (deducted from payout) |
| Payment processing (Stripe) | 2.9% + $0.30 per transaction (absorbed by platform) |
| Dispute resolution (refund) | Platform absorbs Stripe fees on refunded transactions |
