# Metrics Framework: Verified Services Marketplace

**Last Updated:** January 2025

---

## 1. North Star Metric

**Completed jobs with customer satisfaction ≥ 4.0**

This metric captures the marketplace working end-to-end: a customer posted a request, received bids, selected a provider, the work was completed, and the customer was satisfied. It combines marketplace liquidity (enough supply to fulfill demand), quality (verified providers doing good work), and trust (customer confident enough to book and pay through the platform).

**Why not GMV?** GMV can grow while quality declines (more jobs, worse outcomes). A marketplace optimizing for GMV alone will relax verification standards to increase supply, which erodes the trust that is our core value proposition.

**Why not just completed jobs?** A completed job where the customer rates 2.0 is a failure. It generates a dispute, damages brand reputation, and the customer never comes back.

**Baseline:** 0 (new platform)
**Month 6 Target:** 300 satisfied completions/month
**Month 12 Target:** 650 satisfied completions/month
**Current (Month 12):** 683 satisfied completions/month

---

## 2. Input Metrics

These are the levers that drive the North Star. Organized by marketplace side.

### 2.1 Demand Side (Customers)

| Metric | Definition | Target | Current | Measurement |
|---|---|---|---|---|
| Monthly requests posted | Service requests created (excluding drafts) | 800+ | 823 | Platform data |
| Request quality score | % of requests with complete info (category, description >50 chars, location, dates) | > 85% | 79% | Automated scoring on submission |
| Repeat customer rate | % of customers who post 2+ requests within 6 months | > 40% | 44% | Cohort analysis |
| Customer acquisition cost | Blended cost to acquire a booking customer | < $85 | $62 | Marketing spend / new booking customers |
| Request cancellation rate | % of requests cancelled before a bid is accepted | < 10% | 7.3% | Platform data |

### 2.2 Supply Side (Providers)

| Metric | Definition | Target | Current | Measurement |
|---|---|---|---|---|
| Active verified providers | Providers with verified status + at least 1 bid in past 30 days | 300+ | 340 | Platform data |
| Provider activation rate | % of approved providers who complete their first job within 30 days | > 70% | 73% | Cohort analysis |
| Provider utilization | Avg % of provider capacity filled (active jobs / max concurrent) | 40-70% | 52% | Platform data |
| Provider churn (voluntary) | % of active providers who deactivate per month | < 5% | 3.1% | Monthly cohort tracking |
| Avg provider monthly earnings | Mean earnings per active provider | > $3,500 | $3,820 | Payment data |
| Earnings concentration (Gini) | How evenly earnings are distributed across providers | < 0.45 | 0.41 | Monthly Gini calculation |

### 2.3 Matching and Liquidity

| Metric | Definition | Target | Current | Measurement |
|---|---|---|---|---|
| Bid coverage rate | % of requests receiving 3+ bids within 24h | > 80% | 82% | Platform data |
| Time to first bid (median) | Hours from request posted to first bid received | < 6h | 4.2h | Platform timestamps |
| Request fill rate | % of requests that result in a completed booking | > 55% | 58% | Platform data |
| Bid-to-award ratio | Avg bids submitted before a provider wins a job | 2-4 | 3.1 | Platform data |
| Matching accuracy | % of matched providers who submit a bid | > 40% | 44% | Matched providers who bid / total matched |

### 2.4 Quality and Trust

| Metric | Definition | Target | Current | Measurement |
|---|---|---|---|---|
| Customer CSAT | Average composite rating across all completed jobs | > 4.5 | 4.6 | Review data |
| Provider NPS | Net Promoter Score from quarterly provider survey | > 40 | 42 | Survey (quarterly) |
| Dispute rate | Disputes filed / completed jobs | < 5% | 2.1% | Platform data |
| Dispute resolution time | Median business days from filing to resolution | < 5 days | 3.2 days | Platform timestamps |
| No-show rate | Scheduled jobs where provider didn't arrive | < 3% | 1.4% | Customer-reported + system detection |
| Verification pass rate | % of provider applications that pass all checks | 70-80% | 74% | Verification pipeline data |
| Credential currency rate | % of active providers with all credentials current (not expired) | > 95% | 96% | Daily compliance scan |

### 2.5 Financial

| Metric | Definition | Target | Current | Measurement |
|---|---|---|---|---|
| Monthly GMV | Total value of completed transactions | $1.25M by M12 | $1.31M | Payment data |
| Net revenue | Platform fees collected - Stripe processing costs | $190K/mo by M12 | $201K | Financial reporting |
| Average job value | Mean transaction amount (bid amount) | > $1,500 | $1,840 | Payment data |
| Payment failure rate | % of payment attempts that fail | < 3% | 1.8% | Stripe data |
| Provider payout time | Avg business days from job completion to provider receives funds | < 5 days | 3.8 days | Stripe payout data |
| Refund rate | % of captured payments that are refunded (full or partial) | < 5% | 2.9% | Payment data |

---

## 3. Guardrail Metrics

These must not degrade as we optimize for growth. If any guardrail is breached, we pause growth initiatives and investigate.

| Metric | Acceptable Range | Alert Threshold | Why It Matters |
|---|---|---|---|
| Customer CSAT | ≥ 4.3 | < 4.0 | Quality erosion means we're growing supply faster than we can maintain trust |
| Dispute rate | < 5% | > 8% | Rising disputes indicate verification or matching quality problems |
| No-show rate | < 3% | > 5% | Unreliable providers destroy customer trust instantly |
| Credential currency | > 95% | < 90% | Expired credentials mean unverified providers are serving customers |
| Provider involuntary churn | < 5%/mo | > 8%/mo | Removing too many providers signals a verification or SLA calibration problem |
| Earnings Gini coefficient | < 0.50 | > 0.55 | High concentration means most providers are starving while a few dominate — supply-side death spiral |
| Platform uptime | > 99.5% | < 99% | Downtime during active jobs breaks trust on both sides |
| Escrow accuracy | 100% | < 100% | Any payment captured without customer confirmation is a trust violation. Zero tolerance. |
| Data isolation | 100% | < 100% | Customers must never see other customers' data. Providers must never see competing bids. |

---

## 4. Marketplace Health Index

A single composite score (0-100) that summarizes overall marketplace health. Reported weekly to leadership.

```
Marketplace Health Index = (
    0.25 × Liquidity Score +
    0.25 × Quality Score +
    0.20 × Supply Score +
    0.20 × Demand Score +
    0.10 × Financial Score
)
```

**Component calculations:**

| Component | Inputs | Score = 100 | Score = 50 | Score = 0 |
|---|---|---|---|---|
| Liquidity | Bid coverage, time to first bid, fill rate | 90%+ coverage, <4h first bid, 60%+ fill | 70% coverage, 8h first bid, 45% fill | <50% coverage, >16h first bid, <30% fill |
| Quality | CSAT, dispute rate, no-show rate | 4.7+ CSAT, <2% disputes, <1% no-shows | 4.3 CSAT, 5% disputes, 3% no-shows | <4.0 CSAT, >8% disputes, >5% no-shows |
| Supply | Active providers, utilization, churn | 300+ providers, 50-60% util, <3% churn | 200 providers, 35% util, 5% churn | <100 providers, <20% util, >8% churn |
| Demand | Monthly requests, repeat rate, cancellation rate | 800+ requests, 50%+ repeat, <5% cancel | 400 requests, 30% repeat, 10% cancel | <200 requests, <15% repeat, >15% cancel |
| Financial | GMV growth MoM, net revenue, refund rate | 15%+ growth, target revenue, <2% refunds | 5% growth, 80% target, 5% refunds | Negative growth, <50% target, >8% refunds |

**Current Health Index: 81/100**

| Component | Score | Weight | Weighted |
|---|---|---|---|
| Liquidity | 84 | 0.25 | 21.0 |
| Quality | 88 | 0.25 | 22.0 |
| Supply | 76 | 0.20 | 15.2 |
| Demand | 78 | 0.20 | 15.6 |
| Financial | 72 | 0.10 | 7.2 |
| **Total** | | | **81.0** |

**Index interpretation:**
- 85-100: Thriving. Expand to new markets.
- 70-84: Healthy. Optimize existing markets before expanding.
- 55-69: Stressed. Identify and fix weak components before any growth investment.
- Below 55: Critical. All hands on stabilization. Pause expansion, recruitment, and marketing.

---

## 5. Metric Relationships

```
                    ┌──────────────────────────────┐
                    │         NORTH STAR            │
                    │  Completed jobs with          │
                    │  satisfaction ≥ 4.0            │
                    └──────────────┬───────────────┘
                                   │
            ┌──────────────────────┼──────────────────────┐
            │                      │                      │
            ▼                      ▼                      ▼
   ┌─────────────────┐  ┌──────────────────┐  ┌──────────────────┐
   │ DEMAND           │  │ LIQUIDITY        │  │ QUALITY          │
   │                  │  │                  │  │                  │
   │ Requests posted  │  │ Bid coverage     │  │ CSAT             │
   │ Repeat rate      │  │ Time to bid      │  │ Dispute rate     │
   │ Request quality  │  │ Fill rate        │  │ No-show rate     │
   │ Cancellation rate│  │ Bid-to-award     │  │ Completion rate  │
   └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘
            │                      │                      │
            │              ┌───────┴───────┐              │
            │              │               │              │
            ▼              ▼               ▼              ▼
   ┌─────────────────┐  ┌─────────────┐  ┌──────────────────┐
   │ SUPPLY           │  │ MATCHING    │  │ TRUST            │
   │                  │  │             │  │                  │
   │ Active providers │  │ Algorithm   │  │ Verification     │
   │ Utilization      │  │ accuracy    │  │ rate             │
   │ Activation rate  │  │ Notification│  │ Credential       │
   │ Churn            │  │ delivery    │  │ currency         │
   │ Earnings         │  │             │  │ Tier distribution│
   └─────────────────┘  └─────────────┘  └──────────────────┘
            │                                      │
            └──────────────────┬───────────────────┘
                               │
                    ┌──────────┴───────────┐
                    │      GUARDRAILS      │
                    │                      │
                    │ CSAT ≥ 4.3           │
                    │ Dispute rate < 5%    │
                    │ Gini < 0.50          │
                    │ Credential currency  │
                    │ > 95%                │
                    │ Escrow accuracy 100% │
                    └──────────────────────┘
```

---

## 6. Measurement Cadence

| Frequency | Metrics | Forum | Action |
|---|---|---|---|
| **Real-time** | Payment failures, escrow holds, platform uptime, WebSocket connections | Automated dashboards + PagerDuty alerts | On-call engineer responds to critical alerts |
| **Daily** | Requests posted, bids received, bid coverage by market, verification queue depth | Morning standup dashboard | Operator team reviews and acts on market-level gaps |
| **Weekly** | Marketplace Health Index, all input metrics, market-level health, provider engagement | Product team review (Friday) | Prioritize interventions for underperforming markets |
| **Monthly** | Provider tier evaluations, earnings distribution (Gini), churn cohorts, CAC/LTV, financial | Leadership review | Strategic decisions on market expansion, pricing, hiring |
| **Quarterly** | Provider NPS survey, competitive benchmarking, unit economics deep dive, trust incident review | Executive review | Long-term strategy, roadmap adjustments, investment decisions |

---

## 7. Experiments

### 7.1 Completed

| Experiment | Hypothesis | Result | Decision |
|---|---|---|---|
| SMS bid notification | Adding SMS as fallback for providers with push disabled will improve bid coverage | Bid coverage increased from 64% to 74% in test markets | Rolled out to all markets |
| Reduced bid window (24h → 12h) | Shorter bid window will increase urgency and reduce time to first bid | Time to first bid improved 22%, but bid coverage dropped 11% (fewer providers had time to respond) | Reverted to 24h window |
| Provider earnings preview | Showing estimated earnings range on matched jobs will increase bid rate | Bid rate increased 8% on jobs showing earnings estimate | Rolled out to all markets |
| Elite exclusive window | Giving Elite providers 24h exclusive access to high-value jobs before opening to all tiers | Elite bid rate on exclusive jobs: 72% vs. 41% normal. Customer satisfaction on exclusive jobs: 4.8 vs. 4.5 overall | Adopted for jobs > $3,000 |
| Photo requirement for completion | Requiring providers to upload completion photos before marking job done | Dispute rate dropped 18% in test group. Customer trust scores improved. | Rolled out to all categories |
| Dynamic matching radius | Expanding radius by 10 miles in markets with < 70% bid coverage | Bid coverage improved to 78% in thin markets. No negative impact on provider satisfaction. | Adopted for markets below 75% coverage |

### 7.2 Active

| Experiment | Hypothesis | Cohort | Status | Expected Completion |
|---|---|---|---|---|
| Instant booking (skip bidding) | For repeat customer + same provider combos, allow instant booking at last bid price | 15% of repeat bookings | Running 4 weeks | March 2025 |
| Category-specific matching weights | Weighting timeliness higher for emergency services and quality higher for renovation | Emergency plumbing + electrical | Running 2 weeks | February 2025 |
| Provider referral bonus | $200 bonus for referring a provider who completes verification + 3 jobs | All active providers | Running 6 weeks | March 2025 |

### 7.3 Backlog

| Experiment | Hypothesis | Priority | Prerequisite |
|---|---|---|---|
| Dynamic pricing guidance | Showing providers market rate data will reduce bid variance and improve customer conversion | High | 10K+ completed bids in dataset |
| Customer urgency pricing | Customers who mark "urgent" pay a 10% premium, which goes to provider as incentive | Medium | Baseline non-urgent conversion data |
| Tier-based bid ordering | Show Elite bids first to customers (currently chronological) | Medium | Sufficient Elite coverage per market |

---

## 8. Key Metric Insights

### 8.1 The 58% Repeat Booking Insight

Our repeat booking rate (58%) is 3.9x the industry average for open marketplaces (15%). This validates the trust thesis: customers who have a verified, positive experience return to the platform instead of searching elsewhere.

Repeat bookings are also our most profitable transactions: zero customer acquisition cost, higher average job value ($2,100 vs. $1,640 for first-time), and lower dispute rate (0.8% vs. 3.1%).

### 8.2 The Gini Coefficient Watch

We track earnings distribution (Gini coefficient: 0.41) because winner-take-all dynamics kill supply-side marketplaces. If the top 10% of providers earn 80% of GMV, the other 90% starve and leave.

Our tier system deliberately manages this. Elite providers earn more per job (lower fees, priority access), but they also have capacity limits. A 5-job max means Elite providers can't monopolize demand. Standard providers get consistent flow from the jobs Elite providers can't take.

Current distribution:
- Top 10% of providers: 29% of GMV (healthy)
- Middle 50%: 48% of GMV (well-distributed)
- Bottom 40%: 23% of GMV (enough to retain)

### 8.3 The 4.2-Hour First Bid Insight

Median time to first bid (4.2 hours) is our strongest leading indicator of fill rate. Analysis shows:

| Time to First Bid | Fill Rate | Customer Satisfaction |
|---|---|---|
| < 2 hours | 71% | 4.7 |
| 2-6 hours | 61% | 4.6 |
| 6-12 hours | 48% | 4.4 |
| 12-24 hours | 34% | 4.1 |
| > 24 hours | 18% | 3.7 |

Every hour of delay reduces fill rate by approximately 3 percentage points. This is why notification delivery is critical and why we added SMS as a fallback channel.
