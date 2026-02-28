# Product Roadmap: Verified Services Marketplace

**Last Updated:** January 2025

---

## Roadmap Overview

```
Phase 0: Foundation     Phase 1: Marketplace     Phase 2: Scale          Phase 3: Intelligence
(Weeks 1-8)             (Weeks 9-16)             (Weeks 17-24)           (Weeks 25+)

Build core platform     Prove the marketplace    Multi-market expansion  Data-driven features
and seed supply         works with real users    with operational        and advanced
                                                  efficiency              marketplace tools

├─ Provider onboarding  ├─ Customer portal       ├─ Multi-market launch  ├─ Pricing intelligence
├─ Verification         ├─ Bidding flow          ├─ Operator scaling     ├─ Instant booking
│  pipeline             ├─ Escrow payments       │  tools                ├─ Provider analytics
├─ Operator dashboard   ├─ Review system         ├─ Advanced matching    ├─ Demand forecasting
│  (verification queue) ├─ Search + matching     ├─ Dispute automation   ├─ API + integrations
├─ Provider profiles    ├─ Notifications         ├─ Credential auto-     ├─ Customer loyalty
├─ Seed 50 providers    │  (email+SMS+push)      │  renewal              ├─ Dynamic take rate
│  in 3 markets         ├─ In-app messaging      ├─ Performance          └─ White-label
└─ Basic matching       ├─ Operator dispute      │  dashboards               platform
                        │  resolution            ├─ Tier automation
                        └─ 2 live deals          └─ SOC 2 prep
```

---

## Phase 0: Foundation (Weeks 1-8)

**Goal:** Build the core platform, onboard the initial provider network, and validate the verification pipeline.

**Theme:** Can we get 50 providers verified and ready to receive jobs?

| Week | Deliverable | Details |
|---|---|---|
| 1-2 | Provider signup + profile creation | Business name, services, service area (PostGIS point + radius), availability calendar, portfolio photos. Stripe Connect account onboarding integrated into flow. |
| 2-3 | Document upload + automated verification | Upload UI for ID, licenses, insurance. Checkr API integration for identity + background. License number lookup via state APIs (34 states). ACORD insurance form parser for GL/WC validation. |
| 3-4 | Operator verification dashboard | Application queue with status filters. Document viewer. Approve/reject with notes. Phone screen scheduling. Provider communication templates. |
| 4-5 | Provider profile pages | Public profile with services, service area, portfolio, verification badges. Profile only visible after operator approval. |
| 5-6 | Basic matching engine | PostGIS radius query + service type filter + verification status check. Rank by simple composite (rating placeholder until reviews exist). Notify matched providers via email. |
| 6-7 | Seed provider onboarding | White-glove onboarding of top 50 providers from operator's existing network. Pre-populate documents from existing records where available. Personal calls to walk through signup. |
| 7-8 | Internal testing + bug fixes | End-to-end flow testing: provider signup → verification → approval → profile live → receives test job notification. Fix critical issues. |

**Exit Criteria:**
- 50+ providers verified and active across 3 metro markets
- Verification pipeline processes applications in < 48 hours
- 6+ service categories covered per market
- Provider profiles display correctly with verification badges
- Matching engine returns relevant providers within 3 seconds

**Key Risks:**
- State licensing API availability may be spotty. Mitigation: manual verification fallback queue for states without APIs.
- Provider signup friction may cause abandonment. Mitigation: white-glove onboarding for seed cohort, track funnel dropoff for optimization.

---

## Phase 1: Marketplace (Weeks 9-16)

**Goal:** Launch the full marketplace loop. Use on 2+ live deals. Prove liquidity.

**Theme:** Will customers post requests, providers bid, and jobs complete successfully?

| Week | Deliverable | Details |
|---|---|---|
| 9-10 | Customer portal: request posting | Service request form (category, description, location, dates, photos, budget range). Google Maps geocoding on submission. Draft save. Request status tracking. |
| 10-11 | Bidding flow | Providers receive matched job notifications (email + SMS). Bid submission (price, timeline, scope). Customer bid comparison view (side-by-side with provider profiles, ratings, credentials). 24-hour bid window with countdown. |
| 11-12 | Escrow payments | Stripe Connect manual capture on bid acceptance. Customer charged bid + 5% service fee. Payment held in escrow until completion confirmation. Provider payout on T+3-5 after capture. Refund flow for disputes. |
| 12-13 | Review system | Post-completion review prompt. Three-dimension rating (quality, timeliness, communication). Double-blind visibility. Composite rating calculation. Provider response capability. 5-review minimum before public display. |
| 13-14 | Notifications + messaging | Multi-channel notifications (SendGrid email, Twilio SMS, FCM push) based on user preferences. In-app messaging between customer and provider (scoped to request). System messages for status changes. |
| 14-15 | Operator tools: disputes + monitoring | Dispute filing flow (customer submits reason + evidence). Operator review interface (job history, messages, photos). Resolution actions (full refund, partial, dismiss, suspend). Basic marketplace health dashboard (requests, bids, completions, GMV). |
| 15-16 | Live deal execution + iteration | Route real service requests through platform in seed markets. On-call support for first 20 jobs. Daily standup to review issues. Rapid bug fixes and UX adjustments based on live feedback. |

**Exit Criteria:**
- 100+ service requests processed through the platform
- Bid coverage ≥ 80% (3+ bids per request within 24 hours)
- 50+ completed jobs with payment successfully processed
- Customer CSAT ≥ 4.3
- No payment processing failures (escrow holds and captures work correctly)
- Dispute resolution process tested on at least 3 real disputes

**Key Risks:**
- Bid coverage may be below target in early weeks. Mitigation: SMS notification fallback, operator manually routes demand to ensure providers get jobs.
- First payment disputes will test the escrow flow. Mitigation: PM on-call during first 2 weeks of live transactions, manual Stripe intervention capability.

---

## Phase 2: Scale (Weeks 17-24)

**Goal:** Expand to all 12 metro markets. Build operational efficiency to scale without proportionally scaling headcount.

**Theme:** Can this run 12 markets simultaneously without breaking?

| Week | Deliverable | Details |
|---|---|---|
| 17-18 | Multi-market launch framework | Market configuration (matching radius, bid window, fee structure per market). Market-level health dashboard. Launch checklist automation. Provider recruitment pipeline per market. |
| 18-19 | Advanced matching engine | Weighted composite scoring (rating, completion rate, response time, tier, recency). Provider capacity management (max concurrent jobs). Dynamic radius expansion for thin markets. Re-matching when insufficient bids received. |
| 19-20 | Provider tier system | Automated tier evaluation (monthly, trailing 90 days). Standard → Preferred → Elite progression. Tier badges on profiles. Fee adjustment for Elite (12%). Priority matching for higher tiers. Probation period for tier demotion. |
| 20-21 | Operational efficiency tools | Bulk verification actions (approve/reject multiple). Credential expiration monitoring dashboard. Automated reminder sequences (30/14/7 day). Auto-suspend for expired credentials (14-day grace). Template responses for common disputes. |
| 21-22 | Performance dashboards | Provider earnings dashboard (pending, available, paid, lifetime). Market-level analytics (GMV, liquidity, supply/demand balance). Operator productivity metrics. Funnel analytics (signup → verified → first job → retained). |
| 22-23 | Dispute automation | Auto-categorize disputes by type. Suggested resolution based on dispute history. Provider auto-response prompts. Escalation rules (auto-escalate if provider doesn't respond in 48h). Resolution time tracking. |
| 23-24 | SOC 2 preparation + security hardening | Vanta/Drata setup. Policy documentation. Access control audit. Penetration testing. PII handling review. Incident response plan. Data retention enforcement. |

**Exit Criteria:**
- 12 markets live, each with 80%+ bid coverage sustained for 4+ weeks
- 300+ active verified providers across all markets
- Monthly GMV ≥ $1M
- Operator team handles 12 markets without adding headcount (3 → 3 FTE)
- Provider tier system operational with at least 20 Preferred and 5 Elite providers
- SOC 2 readiness assessment completed with no critical gaps

**Key Risks:**
- Rapid market expansion may thin supply. Mitigation: strict launch criteria — no new market until previous market sustains 80% bid coverage for 4 weeks.
- Operator team may be overwhelmed. Mitigation: build automation tools first (weeks 20-21) before adding markets 8-12.

---

## Phase 3: Intelligence (Weeks 25+)

**Goal:** Use accumulated marketplace data to build intelligent features that improve matching, pricing, and retention.

**Theme:** Can the platform get smarter as it scales?

| Deliverable | Details | Priority |
|---|---|---|
| Pricing intelligence | Show providers market rate guidance based on historical bids for similar jobs. Show customers "typical range" for their service type and market. Flag outlier bids (too high or too low). | P0 |
| Instant booking | For repeat customer + same provider, skip bidding. Book at last agreed price (or provider's preset rate). Reduces friction for established relationships. | P0 |
| Provider analytics dashboard | Individual performance trends. Comparison to category averages. Earnings optimization tips ("providers who respond within 2 hours win 40% more jobs"). Tier progress tracker. | P1 |
| Demand forecasting | Predict request volume by category and market (seasonal patterns, day-of-week). Alert providers about upcoming demand. Help operator plan recruitment. | P1 |
| Customer loyalty program | Repeat booking discounts. Loyalty tier (Bronze/Silver/Gold) based on platform usage. Preferred scheduling with favorite providers. | P1 |
| API + integrations | Public API for third-party integrations. Webhook events for job lifecycle. Integration with property management systems, real estate CRMs. | P1 |
| Dynamic take rate | Adjust provider fee based on market conditions. Lower fees in thin markets to attract supply. Higher fees in saturated markets where demand exceeds supply. | P2 |
| White-label platform | Configurable branding for enterprise operators. Custom domains. Branded customer and provider apps. Multi-operator management. | P2 |
| Mobile native apps | iOS and Android apps for providers (job notifications, bid submission, earnings). Customer mobile app for request posting and tracking. | P2 |
| Specialty service modules | Category-specific workflows (e.g., inspections with checklist templates, multi-day renovation with milestone payments). | P3 |

---

## Dependencies and Sequencing

```
Phase 0                     Phase 1                     Phase 2
────────                    ────────                    ────────
Provider signup ──────────► Customer portal              Multi-market config
       │                         │                            │
       ▼                         ▼                            ▼
Verification pipeline ────► Bidding flow ──────────────► Advanced matching
       │                         │                            │
       ▼                         ▼                            ▼
Operator dashboard ────────► Dispute resolution ────────► Dispute automation
       │                         │                            │
       ▼                         ▼                            ▼
Provider profiles ─────────► Review system ─────────────► Tier system
       │                         │                            │
       ▼                         ▼                            ▼
Basic matching ────────────► Notifications + messaging   Performance dashboards
       │                         │                            │
       ▼                         ▼                            ▼
Seed 50 providers ─────────► Escrow payments ───────────► SOC 2 prep
                                 │
                                 ▼
                            Live deal execution
```

---

## Success Milestones

| Milestone | Target Date | Success Criteria |
|---|---|---|
| **Supply seeded** | Week 8 | 50+ verified providers, 3 markets, 6+ categories per market |
| **First completed job** | Week 11 | End-to-end: request → bid → select → escrow → complete → payout → review |
| **Marketplace proved** | Week 16 | 80%+ bid coverage, 50+ completed jobs, CSAT ≥ 4.3, no payment failures |
| **Multi-market live** | Week 20 | 8+ markets live, 200+ providers, $500K+ monthly GMV |
| **Scale achieved** | Week 24 | 12 markets, 300+ providers, $1M+ monthly GMV, SOC 2 ready |
| **Intelligence launched** | Week 30 | Pricing intelligence live, instant booking for repeat customers, provider analytics dashboard |
| **Revenue milestone** | Week 36 | $15M+ annual GMV run rate, $2.5M+ net revenue run rate |

---

## What We're NOT Building (and Why)

| Feature | Why Not | Revisit When |
|---|---|---|
| Provider mobile app (native) | PWA is sufficient for V1. Providers primarily bid from home/office, not in the field. | > 30% of provider sessions are mobile |
| Real-time GPS tracking | Complex, unclear value for scheduled service work (not ride-hailing) | Customer research shows demand for "provider is on the way" visibility |
| Provider financing / cash advances | Regulatory complexity, need lending partner | Provider surveys identify payment timing as top retention factor |
| AI job description enhancement | Premature — manual descriptions work fine | Bid quality correlates with description quality in data analysis |
| Customer-to-customer marketplace | Out of scope — we're B2C2P (business to consumer to provider) | Enterprise requests for customer self-service |
| International expansion | English-only markets for V1-V3, regulatory complexity per country | US markets saturated, international demand demonstrated |
| Insurance claims integration | Would require carrier partnerships, complex to build | Provider property damage rate suggests need for streamlined claims |
| Automated pricing (no bidding) | Insufficient data to set accurate prices. Need 10K+ completed jobs per category. | 10K+ completed jobs per top category |
| Subscription model for customers | Unclear pricing, per-transaction is simpler and more aligned | Repeat booking rate > 60%, customer cohort analysis supports subscription value |
