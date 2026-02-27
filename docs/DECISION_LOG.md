# Decision Log: Verified Services Marketplace

**Last Updated:** January 2025

This document records key technical and product decisions made during the development of the Verified Services Marketplace. Each entry captures the context, options considered, decision made, and the reasoning behind it.

---

## DEC-001: Three Separate Portals vs. Single App with Role Switching

**Date:** February 2024
**Status:** Accepted
**Decider:** Jacob George (PM), Engineering Lead

**Context:**
The platform serves three distinct user types (customers, providers, operators) with fundamentally different workflows. We needed to decide whether to build one application with role-based views or three separate portal experiences.

**Options Considered:**

| Option | Pros | Cons |
|---|---|---|
| **A: Single app, role switching** | One codebase, shared components, simpler deployment | UX compromise for all three roles, complex routing logic, confused navigation, settings/permissions get messy |
| **B: Three separate apps** | Purpose-built UX per role, independent deployment, team can parallelize | Three codebases, duplicated components, higher maintenance |
| **C: Three portals, shared component library** | Purpose-built UX per role, shared UI components via package, independent deployment | Slightly more setup than single app, need component library discipline |

**Decision:** Option C — Three Next.js portals sharing a component library.

**Reasoning:**
- A customer posting a service request and a provider submitting a bid are completely different workflows. Forcing them into one navigation structure means neither experience is great.
- The operator dashboard has tables, metrics, queues, and admin controls that would clutter a customer-facing app.
- A shared component library (buttons, cards, form elements, notification system) gives us consistency without forcing a single app shell.
- Independent deployment means a bug in the operator dashboard doesn't block a customer-facing hotfix.
- Three portals can be built in parallel by different developers without merge conflicts.

**Consequences:**
- Need to maintain a shared component library (@proven/ui) and keep it versioned
- Auth token format must work across all three portals (solved with Supabase Auth + custom claims)
- API layer is shared — all three portals hit the same FastAPI backend

---

## DEC-002: Stripe Connect (Platform Mode) vs. Direct Payments

**Date:** February 2024
**Status:** Accepted
**Decider:** Jacob George (PM), Finance Lead

**Context:**
We needed a payment system that supports escrow (hold funds until job completion), split payments (platform takes a fee, provider gets the rest), and automated payouts to hundreds of providers.

**Options Considered:**

| Option | Pros | Cons |
|---|---|---|
| **A: Stripe Connect (platform/marketplace)** | Built for marketplaces, native escrow (manual capture), split payments, automated payouts, handles KYC/AML and 1099s | 2.9% + $0.30 per transaction, Stripe Connect account onboarding adds friction for providers |
| **B: PayPal Commerce Platform** | Similar marketplace features, PayPal brand recognition | Worse developer experience, higher fees for some transaction types, slower payouts |
| **C: Direct Stripe charges + manual provider payments** | Simpler initial setup, no Connect complexity | Manual payout management at scale is a nightmare, no native escrow, we become responsible for KYC/AML/1099s |
| **D: Square** | Good for in-person payments | Weak marketplace/platform support, no native escrow |

**Decision:** Option A — Stripe Connect in platform mode with manual capture for escrow.

**Reasoning:**
- Manual capture is exactly escrow. We authorize the customer's payment when they select a bid, but don't capture (charge) until they confirm job completion. If there's a dispute, we can adjust the capture amount or release the hold entirely.
- Split payments are native. When we capture, Stripe automatically routes the platform fee to our account and the provider payout to their connected account. No manual calculations or transfers.
- Stripe handles provider KYC/AML verification and 1099 generation. At 340+ providers, doing this ourselves would require a dedicated compliance person.
- Provider onboarding to Stripe Connect takes 5-10 minutes. The friction is real but acceptable — providers understand they need to set up payment info to get paid.
- Automated payouts on T+3-5 schedule. Providers see funds arrive without us doing anything manual.

**Consequences:**
- 2.9% + $0.30 processing fee per transaction (we absorb this, ~$31 on a $1,000 job)
- Provider onboarding includes Stripe Connect account creation — added friction in signup flow
- Tied to Stripe for payment infrastructure (acceptable given their reliability and marketplace tooling)
- Must handle edge cases: expired payment holds (7-day max), partial captures for partial refunds, provider Stripe account issues

---

## DEC-003: PostGIS Radius Matching vs. Zip Code Lookup

**Date:** March 2024
**Status:** Accepted
**Decider:** Jacob George (PM), Engineering Lead

**Context:**
The matching engine needs to find providers within a service radius of each job location. We evaluated two approaches for geospatial matching.

**Options Considered:**

| Option | Pros | Cons |
|---|---|---|
| **A: Zip code lookup table** | Simple, fast, no geospatial extensions needed | Inaccurate at boundaries (zip codes are irregular shapes), can't do true radius, zip code 30301 covers a huge area in Atlanta but 10001 is tiny in Manhattan |
| **B: PostGIS geography queries** | True radius matching (ST_DWithin), accurate distance calculations, handles metro edge cases | Requires PostGIS extension, slightly more complex queries, need to geocode addresses |
| **C: Third-party service (Mapbox Isochrone)** | Drive-time based matching (better than radius), accounts for traffic | External API dependency on critical path, cost scales with queries, latency |

**Decision:** Option B — PostGIS with ST_DWithin for radius matching.

**Reasoning:**
- Zip code boundaries are arbitrary. A provider at the edge of zip code A might be 2 miles from a job in zip code B but excluded because they're in different zip codes. PostGIS handles this correctly with true distance calculations.
- In dense metro areas, a 25-mile radius from downtown Atlanta covers very different territory than 25 miles from suburban Alpharetta. PostGIS calculates actual distance on the WGS 84 ellipsoid — accurate to within meters.
- Supabase includes PostGIS by default. No additional infrastructure needed.
- Google Maps geocoding converts addresses to lat/lng at ingestion time (when customer posts request and when provider sets service area). The geocoding cost is one-time per address, not per match query.
- Query performance with a GIST index on geography columns is excellent. Benchmarked at < 50ms for ST_DWithin against 1,000 provider records.
- Option C (drive-time matching) is better in theory but adds latency and cost to the critical matching path. We can add it later as a re-ranking factor without replacing radius filtering.

**Consequences:**
- All addresses must be geocoded to lat/lng before storage (Google Maps API, ~$5/1000 geocodes)
- Need GIST indexes on geography columns for query performance
- Radius matching doesn't account for drive time (a 20-mile radius across a mountain range vs. along a highway). Acceptable for V1.

**Revisit trigger:** Customer complaints about provider travel time exceeding expectations.

---

## DEC-004: Operator-Gated Verification vs. Self-Serve

**Date:** March 2024
**Status:** Accepted
**Decider:** Jacob George (PM), Operations Lead

**Context:**
The fundamental product question: who controls supply quality? We needed to decide whether providers could self-verify (upload documents and go live immediately) or whether an operator must approve every provider.

**Options Considered:**

| Option | Pros | Cons |
|---|---|---|
| **A: Fully self-serve** | Fastest onboarding, lowest operator cost, scales without headcount | Quality control depends entirely on automated checks, no portfolio/phone screen, bad providers get through |
| **B: Automated checks + operator approval** | Automated checks filter obvious failures, operator adds judgment layer (portfolio, references, phone screen) | Slower onboarding (adds 24-48h), operator team must scale with provider volume |
| **C: Fully manual (operator does everything)** | Maximum quality control | Doesn't scale, operator becomes bottleneck, weeks-long verification |

**Decision:** Option B — Automated checks first, operator approval second.

**Reasoning:**
- Trust is the product. If we let anyone with a valid license self-serve onto the platform, we lose the quality signal that justifies our take rate. Customers pay our fee because they trust our verification.
- Automated checks (Checkr background, license API lookup, insurance parsing) catch 26% of applicants who would otherwise be rejected. These are clear failures (expired license, criminal record, insufficient insurance). No human judgment needed.
- The remaining 74% who pass automated checks still need operator review. A valid license doesn't mean quality work. The phone screen and portfolio review catch providers who are technically qualified but wrong for the platform (poor communication, unprofessional presentation, limited portfolio).
- Operator approval adds 24-48 hours to onboarding. This is acceptable because providers expect a verification process (it signals that the platform is serious about quality). Instant approval would actually reduce trust.
- The operator team (3 people) can handle ~120 applications/month at current volume. We'll need to hire as we scale past 150/month, but the cost is justified by the quality premium.

**Consequences:**
- Operator headcount must scale with provider application volume (~1 reviewer per 50 applications/month)
- 24-48 hour onboarding delay may lose impatient providers to competitors
- Need to track verification funnel conversion to ensure we're not losing good providers to friction

**Revisit trigger:** Application-to-approval rate drops below 50% (too many good providers abandoning) OR operator team exceeds 6 people (cost efficiency concern).

---

## DEC-005: Weighted Composite Rating vs. Simple Average

**Date:** April 2024
**Status:** Accepted
**Decider:** Jacob George (PM)

**Context:**
We needed a rating system that gives customers useful information and gives providers actionable feedback. A simple 5-star average was the obvious default, but we questioned whether it was sufficient.

**Analysis:**

We analyzed 200 reviews from the operator's pre-platform feedback records and coded each for quality, timeliness, and communication dimensions:

| Scenario | Quality | Timeliness | Communication | Simple Avg | Composite (50/30/20) |
|---|---|---|---|---|---|
| Great work, always late, poor communicator | 5 | 2 | 2 | 3.0 | 3.5 |
| Average work, always on time, very responsive | 3 | 5 | 5 | 4.3 | 4.0 |
| Excellent all around | 5 | 5 | 5 | 5.0 | 5.0 |
| Great work, great communication, sometimes late | 5 | 3 | 5 | 4.3 | 4.4 |

**Decision:** Weighted composite rating (Quality 50%, Timeliness 30%, Communication 20%).

**Reasoning:**
- The simple average treats all dimensions equally, but they're not equally important. A plumber who does flawless work but is 30 minutes late is better than a plumber who shows up on time but doesn't fix the leak.
- Scenario 1 (great work, always late) should score higher than scenario 2 (average work, always on time) because the customer hired a provider for quality outcomes, not punctuality. The composite correctly ranks scenario 1 at 3.5 and scenario 2 at 4.0 — close, but the on-time average worker edges ahead because chronic lateness is a real problem. Simple average would incorrectly rate scenario 2 a full 1.3 points higher.
- Showing dimension scores alongside the composite gives providers specific feedback: "Your quality is great (4.8) but your timeliness is hurting you (3.2). Here are tips for improving scheduling accuracy."
- Customers see the composite for quick comparison and can drill into dimensions if they care about specific attributes (e.g., a customer scheduling around a work meeting might prioritize timeliness).

**Consequences:**
- More complex review form (three ratings instead of one). Mitigated with star rating UI — takes 3 taps instead of 1.
- Need to educate providers on how the composite is calculated
- Weight calibration may need adjustment as we gather more data on what actually predicts rebooking

**Revisit trigger:** Rebooking correlation analysis with 5,000+ reviews — do the weights match actual rebooking predictors?

---

## DEC-006: 24-Hour Bid Window vs. Shorter/Longer

**Date:** April 2024
**Status:** Accepted (revised from 12-hour experiment)
**Decider:** Jacob George (PM)

**Context:**
The bid window determines how long providers have to bid on a job before bidding closes and the customer selects. Too short and providers don't have time to respond. Too long and customers wait impatiently.

**Experiment:**

We tested three bid windows over 4 weeks:

| Window | Avg Bids/Request | Bid Coverage (3+) | Time to Customer Decision | Customer Satisfaction |
|---|---|---|---|---|
| 12 hours | 2.4 | 58% | 14.2 hours | 4.3 |
| 24 hours | 3.8 | 82% | 26.1 hours | 4.6 |
| 48 hours | 4.2 | 87% | 44.8 hours | 4.2 |

**Decision:** 24-hour bid window.

**Reasoning:**
- 12 hours had the fastest customer decision time but significantly lower bid coverage (58% vs. 82%). Many providers check the app once or twice a day and missed the window entirely. Customers got fewer options and lower satisfaction.
- 48 hours marginally improved bid coverage (87% vs. 82%) but nearly doubled the time to customer decision. The extra 5% coverage wasn't worth waiting an additional 18 hours. Customer satisfaction actually declined because of the wait.
- 24 hours hits the sweet spot: enough time for providers in different time zones and with varying app-check habits to respond, but not so long that customers feel they're waiting forever.
- Adding SMS notifications for providers who haven't opened the app within 6 hours further improved the 24-hour window's bid coverage from 74% to 82%.

**Consequences:**
- Customers may see bids trickle in over 24 hours (managed with real-time WebSocket notifications)
- Some urgent requests (burst pipe, electrical emergency) need a shorter window. Future: add "urgent" flag with 4-hour window and premium pricing.
- The 24-hour clock starts when matching is complete (typically 1-5 minutes after posting), not when the request is created

---

## DEC-007: 15% Provider Fee + 5% Customer Fee vs. Alternatives

**Date:** May 2024
**Status:** Accepted
**Decider:** Jacob George (PM), Finance Lead

**Context:**
Marketplace take rate is one of the most consequential product decisions. Too high and providers leave or inflate prices. Too low and the business can't sustain operations.

**Options Considered:**

| Option | Provider Fee | Customer Fee | Blended Take Rate | Annual Revenue (at $15M GMV) |
|---|---|---|---|---|
| **A: Provider only (20%)** | 20% | 0% | 20% | $3.0M |
| **B: Split (15% + 5%)** | 15% | 5% | ~17% net (after Stripe) | $2.55M |
| **C: Customer only (20%)** | 0% | 20% | 20% | $3.0M |
| **D: Low take (10% + 3%)** | 10% | 3% | ~11% net | $1.65M |
| **E: Lead fee model** | $25-75 per lead | 0% | Variable | Unpredictable |

**Decision:** Option B — 15% provider fee + 5% customer fee (~17% net blended take rate).

**Reasoning:**

*Why split the fee:*
- Provider-only fees create resentment ("I do all the work and the platform takes 20%"). Splitting the cost makes both sides feel the fee is reasonable.
- A 5% customer fee is low enough that customers perceive it as a reasonable cost for verification, escrow protection, and convenience. Framed as a "service fee" alongside the bid amount.
- 15% provider fee is below the industry average for lead-based models (Thumbtack: 15-30%, Angi: 15-65%) and competitive with percentage-based models (TaskRabbit: 15%).

*Why not higher:*
- At 20%+ provider fees, providers start quoting higher to maintain their net earnings. This makes the marketplace less competitive vs. direct hiring.
- Provider surveys indicated 15% was the maximum acceptable fee. Above that, 40% of providers said they'd consider leaving.

*Why not lower:*
- At 11% net (Option D), annual revenue of $1.65M doesn't cover operations: operator team (3 FTE, ~$300K), engineering (4 FTE, ~$600K), infrastructure (~$120K), Stripe fees (~$450K at $15M GMV). We'd be unprofitable.
- At 17% net, we have $2.55M revenue vs. ~$1.5M costs = healthy margin for growth investment.

*Why not lead fees:*
- Lead-based pricing (Option E) is unpredictable for providers. A $50 lead fee for a job they don't win is frustrating. Percentage-based fees align platform incentives with provider success — we only earn when they earn.

**Consequences:**
- Elite tier discount (12% instead of 15%) reduces margin on top providers but drives loyalty and GMV concentration in highest-quality providers
- Platform absorbs Stripe processing fees (2.9% + $0.30) to keep the fee structure clean and transparent
- Must monitor provider pricing behavior — if average bids increase post-launch, providers may be passing the fee to customers

---

## DEC-008: Bidding Model vs. Instant Booking with Fixed Pricing

**Date:** March 2024
**Status:** Accepted
**Decider:** Jacob George (PM)

**Context:**
We needed to decide how customers and providers agree on pricing. The two models: providers bid on each job (auction-like) or the platform sets fixed prices and customers book instantly.

**Options Considered:**

| Option | Pros | Cons |
|---|---|---|
| **A: Provider bidding** | Providers price for actual job complexity, competitive pricing benefits customers, providers feel ownership of their pricing | Slower (customer must wait for bids), more complex UX, price variance may confuse customers |
| **B: Fixed pricing by platform** | Instant booking, predictable pricing, simpler UX | Can't account for job complexity, providers feel commoditized, platform takes pricing risk |
| **C: Hybrid (fixed for simple, bidding for complex)** | Best of both for different job types | Complex to implement and explain, need to categorize every service type |

**Decision:** Option A — Provider bidding for all jobs in V1.

**Reasoning:**
- Service work varies enormously. "Fix a leaky faucet" could be a $150 cartridge replacement or a $2,000 pipe rework. Fixed pricing would either overprice simple jobs (losing customers) or underprice complex ones (losing providers).
- Bidding creates competition that benefits customers. When 3-4 providers bid on a job, the customer gets market-rate pricing without us having to set prices.
- Providers are skilled tradespeople who understand their costs. They can price for travel distance, job complexity, materials, and their availability. Fixed pricing strips this expertise.
- The bidding UX is manageable because we show bids in a comparison view with provider profiles, ratings, and credentials alongside the price. Customers aren't just picking the cheapest — they're evaluating value.
- Option C (hybrid) is our likely future state but premature for V1. We need 10K+ completed jobs to have enough data to set accurate fixed prices for any service type.

**Consequences:**
- Customer must wait for bids (addressed with 24-hour window and real-time notifications)
- Price variance on similar jobs. Mitigated by showing customers "typical range for this service in your area" (once we have enough data)
- Provider bid quality matters — need scope of work descriptions, not just price

**Revisit trigger:** When we have 10K+ completed jobs, revisit hybrid model for the most standardized service categories (e.g., standard home cleaning).

---

## DEC-009: Double-Blind Reviews

**Date:** April 2024
**Status:** Accepted
**Decider:** Jacob George (PM)

**Context:**
Review systems are vulnerable to retaliation. If a customer sees the provider gave them a bad review, they might change their own review to be negative. If a provider sees a negative customer review before responding, they might leave a retaliatory response.

**Options Considered:**

| Option | Pros | Cons |
|---|---|---|
| **A: Fully visible (both see immediately)** | Simple, transparent | Retaliation risk, first-mover advantage (whoever reviews first sets the tone) |
| **B: Double-blind (hidden until both submit)** | Eliminates retaliation, honest ratings | Slight delay in review visibility, one party may never submit |
| **C: Customer review only** | Simple, no retaliation | Providers have no feedback mechanism, feels one-sided |

**Decision:** Option B — Double-blind with 7-day auto-reveal window.

**Reasoning:**
- Airbnb pioneered double-blind reviews and saw review accuracy improve significantly after implementing it. We adopted the same pattern.
- Neither party sees the other's review until both have submitted. This eliminates the retaliation dynamic entirely.
- If one party doesn't submit within 7 days, the submitted review becomes visible anyway. This prevents the scenario where a provider never submits to keep a negative customer review hidden.
- Honest reviews are the foundation of the reputation layer. Any mechanism that discourages honesty (like visible reviews that invite retaliation) degrades the trust system.

**Consequences:**
- Reviews may not be visible for up to 7 days after job completion (if one party delays)
- Need clear communication to both parties: "Your review will be visible once both parties have submitted, or after 7 days"
- Provider composite ratings may lag slightly due to review visibility delay

---

## DEC-010: Earnings Gini Coefficient as a Guardrail

**Date:** June 2024
**Status:** Accepted
**Decider:** Jacob George (PM)

**Context:**
Marketplaces naturally concentrate earnings in top performers. This is partially healthy (best providers should earn more) but becomes toxic when the majority of providers can't earn enough to stay engaged. We needed a way to monitor and manage this.

**Options Considered:**

| Option | Pros | Cons |
|---|---|---|
| **A: No monitoring** | Simple, let the market decide | Risk: winner-take-all dynamics silently kill supply side |
| **B: Cap max jobs per provider** | Directly limits concentration | Punishes best providers, feels arbitrary, hard to set right number |
| **C: Monitor Gini coefficient + tiered interventions** | Data-driven, interventions are graduated, doesn't cap success but ensures baseline participation | Gini is a lagging indicator, requires monthly analysis |

**Decision:** Option C — Monitor Gini coefficient monthly with intervention thresholds.

**Reasoning:**
- The Gini coefficient (0 = perfect equality, 1 = one provider earns everything) is a well-understood measure of distribution fairness. Applied to provider earnings, it tells us whether the marketplace is healthy or concentrating.
- Our target range is 0.30-0.45. Below 0.30 means insufficient differentiation (best providers aren't rewarded). Above 0.45 means excessive concentration (most providers are starving).
- Rather than hard caps on successful providers, we use soft interventions: diversifying matching weights, ensuring "new provider" visibility, and category-level liquidity management.
- The tier system with capacity limits (max 5 concurrent jobs) naturally prevents extreme concentration while still rewarding quality.

**Intervention thresholds:**

| Gini | Status | Action |
|---|---|---|
| 0.30-0.45 | Healthy | No action needed |
| 0.45-0.50 | Watch | Analyze which categories/markets are concentrating. Increase matching diversity weight. |
| 0.50-0.55 | Warning | Introduce "new provider" boost in matching. Review if specific providers are monopolizing categories. |
| > 0.55 | Critical | Active intervention: reduce max concurrent for top earners, increase matching radius to bring in more supply, review tier criteria |

**Current:** 0.41 (healthy range)

**Consequences:**
- Monthly analysis required (automated report, 10-minute review)
- May need to make unpopular decisions (reducing top provider visibility) if concentration gets extreme
- Gini is a lagging indicator — by the time it spikes, providers may have already churned

---

## DEC-011: Celery + Redis vs. Temporal for Task Orchestration

**Date:** March 2024
**Status:** Accepted
**Decider:** Jacob George (PM), Engineering Lead

**Context:**
The platform has multiple async workflows: matching engine execution, notification dispatch (email + SMS + push), verification webhook processing, payment capture/payout, credential expiration monitoring. We needed a task orchestration system.

**Options Considered:**

| Option | Pros | Cons |
|---|---|---|
| **A: Celery + Redis** | Mature, well-documented, team knows it, simple setup, large community | No native workflow orchestration (just tasks), retry logic is basic, monitoring requires separate tool (Flower) |
| **B: Temporal** | True workflow orchestration, durable execution, built-in retry/timeout, great visibility | Steep learning curve, heavier infrastructure (Temporal server + database), smaller community |
| **C: AWS SQS + Lambda** | Serverless, scales automatically, pay-per-use | AWS lock-in, cold start latency, complex local development, harder to test |

**Decision:** Option A — Celery + Redis.

**Reasoning:**
- Our workflows are relatively simple: trigger task → execute → handle success/failure. We don't have long-running sagas or complex compensation logic that would justify Temporal's overhead.
- The team has production experience with Celery. Temporal would require 2-3 weeks of learning before productive work begins.
- Redis (via Upstash) serves double duty: Celery broker and application cache (rate limiting, session data, matching results). One service, two purposes.
- Celery's retry mechanism (exponential backoff, max retries, dead letter queue) is sufficient for our failure modes: transient API failures (Checkr, Stripe, notification services).
- If we outgrow Celery, Temporal is a clean migration path. Task signatures are similar and the workflow logic lives in our code, not in Celery-specific constructs.

**Consequences:**
- Complex workflows (multi-step verification with branching logic) require careful task chaining
- Need Flower or custom dashboard for task monitoring
- Redis is a single point of failure for async tasks (mitigated by Upstash's managed Redis with replication)

**Revisit trigger:** If we add workflow complexity (multi-step approval chains, long-running sagas, complex compensation) that requires true orchestration.

---

## DEC-012: Absorb Stripe Processing Fees vs. Pass to Provider

**Date:** May 2024
**Status:** Accepted
**Decider:** Jacob George (PM), Finance Lead

**Context:**
Stripe charges 2.9% + $0.30 per transaction. On a $1,000 job, that's $29.30. We needed to decide who bears this cost.

**Options Considered:**

| Option | Impact on $1,000 Job |
|---|---|
| **A: Platform absorbs** | Provider gets $850 (bid - 15% fee). Platform nets $150 - $29.30 = $120.70 |
| **B: Provider pays** | Provider gets $850 - $29.30 = $820.70. Platform nets $150 |
| **C: Customer pays** | Customer pays $1,050 (bid + 5% fee) + $29.30 = $1,079.30. Platform nets $150 |
| **D: Split between provider and customer** | Each pays ~$14.65. Complex to explain. |

**Decision:** Option A — Platform absorbs Stripe fees.

**Reasoning:**
- Provider earnings transparency. When a provider bids $1,000 and we say "you'll receive $850" (bid minus 15% fee), that's clean and predictable. Subtracting a variable processing fee makes the math confusing and feels like a hidden charge.
- Customer experience. The customer sees "bid: $1,000 + service fee: $50 = total: $1,050." Adding a separate processing fee line item looks nickel-and-dime.
- At our current GMV ($15M/year), Stripe fees total approximately $450K annually. Our platform fee revenue is approximately $2.55M. Absorbing $450K leaves $2.1M — still healthy margin.
- Stripe fees are a cost of doing business, like hosting or email delivery. We don't pass those to users either.

**Consequences:**
- ~$450K/year reduction in net revenue (factored into unit economics)
- If Stripe raises rates, we absorb the increase (or renegotiate — at $15M GMV we have some leverage)
- Simpler provider and customer communications around pricing
