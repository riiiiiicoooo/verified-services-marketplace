# Trust Framework: Verified Services Marketplace

**Last Updated:** January 2025

---

## 1. Trust as the Core Product

Open marketplaces compete on volume. We compete on trust. The platform operator sits between providers and customers as a verification authority, quality enforcer, and dispute arbiter. Every design decision in this framework answers one question: does this increase or decrease the customer's confidence that the provider will deliver quality work?

Trust is not a feature. It is the product. Remove it and we're a worse version of Craigslist.

---

## 2. The Trust Stack

Trust is built in layers. Each layer must be intact for the layer above it to matter.

```
┌─────────────────────────────────────────────┐
│  Layer 5: REPUTATION                         │
│  Earned through performance over time        │
│  Reviews, ratings, tier badges, repeat rate  │
├─────────────────────────────────────────────┤
│  Layer 4: FINANCIAL PROTECTION               │
│  Money is safe until work is done            │
│  Escrow, dispute resolution, refund policy   │
├─────────────────────────────────────────────┤
│  Layer 3: ACCOUNTABILITY                     │
│  Actions have consequences                   │
│  Audit trail, SLA monitoring, suspension     │
├─────────────────────────────────────────────┤
│  Layer 2: QUALIFICATION                      │
│  Provider can do the work                    │
│  Trade licenses, insurance, skills           │
├─────────────────────────────────────────────┤
│  Layer 1: IDENTITY                           │
│  Provider is who they say they are           │
│  ID verification, background check           │
└─────────────────────────────────────────────┘
```

A provider with a great reputation (Layer 5) but expired insurance (Layer 2) is not trustworthy. A provider with valid credentials (Layer 2) but no financial protection for the customer (Layer 4) is a risk. Every layer must hold.

---

## 3. Layer 1: Identity Verification

### 3.1 Process

Every provider must pass identity verification before any other checks proceed. This is the foundation.

| Check | Vendor | Method | Turnaround | Pass Criteria |
|---|---|---|---|---|
| Government ID verification | Checkr | Document scan + facial match | 1-24 hours | ID is authentic, not expired, matches applicant |
| Criminal background check | Checkr | County, state, federal database search | 24-72 hours | No felony convictions in past 7 years; no misdemeanors involving theft, fraud, or violence in past 5 years |
| Sex offender registry | Checkr | National registry search | Included in background | Not on any registry |
| SSN trace | Checkr | Address history verification | Included in background | SSN valid, no identity fraud flags |

### 3.2 Criminal Background Policy

We follow a fair-chance approach consistent with EEOC guidance and Ban-the-Box legislation in applicable states:

**Automatic disqualification:**
- Any felony conviction involving violence against persons (no time limit)
- Any sex offense (no time limit)
- Felony fraud or theft within past 7 years
- Active warrant or pending felony charge

**Individualized assessment (operator review):**
- Misdemeanor convictions within past 5 years (evaluated for relevance to service type)
- Felony convictions older than 7 years (evaluated on rehabilitation evidence)
- Multiple misdemeanors (pattern analysis)

**Not considered:**
- Arrests without conviction
- Expunged or sealed records
- Infractions and traffic violations (unless CDL-required service)

### 3.3 Identity Re-verification

- Government ID: re-verified annually
- Background check: refreshed every 2 years for Standard/Preferred, annually for Elite (higher trust expectation)
- Provider must consent to ongoing monitoring at signup

---

## 4. Layer 2: Qualification Verification

### 4.1 Trade License Verification

```
Provider enters license number + state
                │
                ▼
        ┌───────────────────┐
        │ State API lookup   │ (available in 34 states)
        │ available?         │
        ├───────┬───────────┤
        │  Yes  │    No     │
        │       │           │
        ▼       │           ▼
  ┌──────────┐  │   ┌──────────────────┐
  │ API call  │  │   │ Manual           │
  │           │  │   │ verification     │
  │ Validate: │  │   │                  │
  │ - Active  │  │   │ Operator checks: │
  │ - Not     │  │   │ - State website  │
  │   expired │  │   │ - Phone call to  │
  │ - Correct │  │   │   licensing board│
  │   type    │  │   │ - Document review│
  │ - Matches │  │   │                  │
  │   provider│  │   │ Turnaround:      │
  │   name    │  │   │ 1-3 business days│
  │           │  │   │                  │
  │ Turnaround│  │   └────────┬─────────┘
  │ < 1 min   │  │            │
  └─────┬─────┘  │            │
        │        │            │
        └────────┴────────────┘
                │
                ▼
        ┌───────────────────┐
        │ Store:             │
        │ - License number   │
        │ - License type     │
        │ - Issuing state    │
        │ - Expiration date  │
        │ - Verification     │
        │   method (api/     │
        │   manual)          │
        │ - Verified date    │
        └───────────────────┘
```

**License requirements by service category:**

| Category | Required License Type | States With API |
|---|---|---|
| Plumbing | Journeyman/Master Plumber | 28 |
| Electrical | Journeyman/Master Electrician | 31 |
| HVAC | HVAC Contractor License + EPA 608 | 26 |
| General Contracting | General Contractor License | 34 |
| Roofing | Roofing Contractor License | 22 |
| Pest Control | Pest Control Applicator License | 30 |
| Painting | Contractor License (where required) | Varies |
| Landscaping | Landscape Contractor (where required) | Varies |
| Cleaning | Business License only | N/A |
| Flooring | Contractor License (where required) | Varies |

### 4.2 Insurance Verification

**Required coverage:**

| Coverage Type | Minimum | Required For |
|---|---|---|
| General Liability (GL) | $1,000,000 per occurrence | All providers |
| Workers' Compensation | State minimum | Providers with employees |
| Commercial Auto | $500,000 combined | Providers using vehicles for service delivery |

**Verification process:**

```
Provider uploads Certificate of Insurance (ACORD 25/28)
                │
                ▼
        ┌───────────────────┐
        │ ACORD form parser  │
        │                    │
        │ Extract:           │
        │ - Carrier name     │
        │ - Policy number    │
        │ - Coverage limits  │
        │ - Effective dates  │
        │ - Named insured    │
        │ - Certificate      │
        │   holder           │
        └────────┬──────────┘
                 │
                 ▼
        ┌───────────────────┐
        │ Automated checks:  │
        │                    │
        │ ✓ GL ≥ $1M?       │
        │ ✓ Not expired?     │
        │ ✓ Expiry > 30 days │
        │   from now?        │
        │ ✓ Named insured    │
        │   matches provider?│
        └────────┬──────────┘
                 │
           ┌─────┴─────┐
           │           │
         Pass        Fail
           │           │
           ▼           ▼
     ┌──────────┐ ┌──────────────┐
     │ Approved  │ │ Rejection    │
     │           │ │ with specific│
     │           │ │ reason:      │
     │           │ │ "GL coverage │
     │           │ │  is $500K,   │
     │           │ │  minimum is  │
     │           │ │  $1M"        │
     └──────────┘ └──────────────┘
```

### 4.3 Credential Expiration Monitoring

Credentials expire. A provider verified in January may have an expired license by July. The platform must continuously monitor.

**Daily cron job checks all active providers:**

```
For each verification where status = 'passed' AND expires_at IS NOT NULL:

  IF expires_at - NOW() <= 30 days AND NOT reminder_30d_sent:
    → Send email: "Your [license type] expires on [date]. Upload renewed document to maintain your verified status."
    → Set reminder_30d_sent = true

  IF expires_at - NOW() <= 14 days AND NOT reminder_14d_sent:
    → Send email + SMS: "Your [license type] expires in [days]. Upload now to avoid service interruption."
    → In-app alert badge on provider dashboard
    → Set reminder_14d_sent = true

  IF expires_at - NOW() <= 7 days AND NOT reminder_7d_sent:
    → Send email + SMS + push: "URGENT: [license type] expires in [days]. Your profile will be suspended if not renewed."
    → Alert operator dashboard: "Provider [name] credential expiring"
    → Set reminder_7d_sent = true

  IF expires_at < NOW():
    → Start 14-day grace period
    → Provider can complete active jobs but cannot receive new matches
    → Badge on profile: "Credential renewal in progress"

  IF expires_at < NOW() - 14 days:
    → Auto-suspend provider
    → Remove from matching pool
    → Notify provider: "Your account has been suspended due to expired [credential type]"
    → Notify operator for follow-up
```

**Renewal rates (actual):**
- 30-day reminder: 34% renew within 7 days of reminder
- 14-day reminder: 28% renew (cumulative: 62%)
- 7-day reminder: 22% renew (cumulative: 84%)
- Grace period: 11% renew (cumulative: 95%)
- Suspended: 5% never renew (churn)

---

## 5. Layer 3: Accountability

### 5.1 SLA Monitoring

Every provider's behavior is tracked against service level expectations:

| Metric | Expectation | Measurement | Consequence of Violation |
|---|---|---|---|
| Response time | Bid within 12 hours of notification | Time from notification to first bid | Warning after 3 consecutive missed bid windows |
| No-show rate | < 3% of scheduled jobs | Provider fails to arrive within 1 hour of scheduled time | Warning at 3%; probation at 5%; suspension at 8% |
| Completion rate | > 95% of accepted jobs completed | Jobs completed / jobs accepted | Warning below 93%; probation below 90%; suspension below 85% |
| Dispute rate | < 5% of completed jobs | Disputes filed / completed jobs | Warning at 5%; probation at 8%; suspension at 10% |
| Rating floor | Composite ≥ 3.5 | Rolling 90-day composite rating | Warning at 3.7; probation at 3.5; suspension at 3.0 |

### 5.2 Progressive Discipline

```
Violation detected
        │
        ▼
┌───────────────────┐
│ First offense:     │
│ WARNING            │
│                    │
│ - Email to provider│
│ - In-app notice    │
│ - Note in provider │
│   file             │
│ - No impact on     │
│   matching or tier │
└────────┬──────────┘
         │
    Repeated within 90 days?
         │
         ▼
┌───────────────────┐
│ Second offense:    │
│ PROBATION (30 day) │
│                    │
│ - Reduced matching │
│   priority (-20%)  │
│ - Operator review  │
│   scheduled        │
│ - Provider must    │
│   acknowledge and  │
│   create action    │
│   plan             │
└────────┬──────────┘
         │
    Another violation during probation?
         │
         ▼
┌───────────────────┐
│ Third offense:     │
│ SUSPENSION         │
│                    │
│ - Removed from     │
│   matching pool    │
│ - Active jobs can  │
│   complete         │
│ - Operator review  │
│   required for     │
│   reinstatement    │
│ - Minimum 30-day   │
│   suspension       │
└────────┬──────────┘
         │
    Reinstatement review
         │
    ┌────┴────┐
    │         │
 Reinstated  Permanent
 (probation   removal
  for 90     (pattern of
  days)       violations
              or severe
              misconduct)
```

### 5.3 Immediate Suspension Triggers

Some violations bypass progressive discipline and result in immediate suspension pending investigation:

- Customer reports property damage > $1,000
- Customer reports threatening or abusive behavior
- Provider found operating without valid license (was valid at verification, has since been revoked)
- Provider found to have misrepresented credentials during onboarding
- Fraudulent billing (charging customer outside the platform for platform-booked work)
- Any criminal charge relevant to service delivery (reported via Checkr continuous monitoring)

### 5.4 Audit Trail

Every trust-relevant action is logged immutably:

| Event | Data Captured |
|---|---|
| Provider application submitted | All submitted documents and profile data |
| Verification check result | Check type, vendor, result, timestamp, reviewer (if manual) |
| Provider approved/rejected | Decision, reviewer, reason, timestamp |
| SLA violation detected | Violation type, metric value, threshold, affected job |
| Warning issued | Violation details, communication sent, provider acknowledgment |
| Probation started/ended | Reason, terms, duration, outcome |
| Suspension started/ended | Reason, duration, reinstatement reviewer, conditions |
| Dispute filed | All dispute details, evidence, communications |
| Dispute resolved | Resolution, rationale, refund amount, reviewer |
| Tier change | Old tier, new tier, qualifying metrics, effective date |
| Credential expired | Credential type, expiry date, reminder history, actions taken |

---

## 6. Layer 4: Financial Protection

### 6.1 Escrow Flow

Customers never pay providers directly. All payments flow through the platform with escrow protection.

```
Customer selects bid ($1,000 job)
        │
        ▼
Customer charged: $1,050 (bid + 5% service fee)
        │
        ▼
Stripe holds $1,050 (PaymentIntent with manual capture)
        │
        ▼
Provider completes work
        │
        ▼
Customer confirms: "Work is complete and satisfactory"
        │
        ▼
Payment captured:
├── Platform retains: $200 ($50 customer fee + $150 provider fee)
├── Provider receives: $850 ($1,000 - $150 platform fee)
├── Stripe processing: ~$31 (2.9% + $0.30, absorbed by platform)
└── Net platform revenue: $169 ($200 - $31 Stripe fee)
        │
        ▼
Provider payout: $850 in 3-5 business days via Stripe automated payouts
```

### 6.2 Dispute Resolution

When a customer is not satisfied, the dispute process protects both parties:

```
Customer files dispute
├── Selects reason (incomplete work, poor quality, no-show, etc.)
├── Describes issue
├── Uploads evidence photos
        │
        ▼
Provider notified (48 hours to respond)
├── Provider can accept fault (immediate resolution)
├── Provider can dispute the claim with evidence
├── Provider can propose compromise
        │
        ▼
Operator reviews (if provider disputes)
├── Reviews job photos (before/during/after)
├── Reviews message history
├── Reviews provider's track record
├── May request additional information from either party
        │
        ▼
Operator makes ruling
├── Full refund → Customer refunded 100%, provider receives nothing
├── Partial refund → Negotiated amount (e.g., 50% for incomplete work)
├── Dismissed → No refund, customer claim not substantiated
├── Provider suspended → Refund + provider removed from platform
        │
        ▼
Ruling communicated to both parties
├── Email with explanation and rationale
├── Either party can appeal once (escalated to senior operator)
```

**Dispute resolution targets:**
| Metric | Target | Actual |
|---|---|---|
| Provider response within 48h | > 90% | 93% |
| Resolution within 5 business days | > 85% | 87% |
| Customer satisfaction with resolution | > 75% | 78% |
| Appeal rate | < 15% | 12% |

**Dispute outcomes (trailing 12 months):**
| Outcome | Percentage |
|---|---|
| Full refund | 18% |
| Partial refund | 34% |
| Dismissed (no refund) | 31% |
| Provider accepts fault (pre-review) | 14% |
| Withdrawn by customer | 3% |

### 6.3 Fraud Prevention

| Fraud Type | Detection | Prevention |
|---|---|---|
| Fake provider accounts | Checkr identity verification, SSN trace, duplicate detection | Cannot create account without verified identity |
| Fake reviews | Pattern detection (multiple reviews from new accounts, review timing clusters) | Minimum account age for reviews, operator moderation queue |
| Bid manipulation | Price analytics (flag bids 3+ standard deviations from market) | Operator review of outlier bids |
| Fake service requests | Customer identity verification for requests > $5,000, payment method verification | Require valid payment method before posting |
| Provider collusion | Monitor bid patterns (same providers always bidding together, similar pricing) | Algorithmic detection + operator investigation |
| Stolen credentials | Continuous background monitoring via Checkr, license expiration tracking | Auto-suspend on credential change |

---

## 7. Layer 5: Reputation

### 7.1 Rating System Design

**Why weighted composite instead of simple average:**

A simple 5-star average conflates different dimensions of quality. A plumber who does excellent work (5 stars) but is chronically late (2 stars) and never responds to messages (2 stars) looks like a 3-star provider — same as a mediocre-at-everything provider. The composite system separates these dimensions so customers can make informed choices and providers know specifically what to improve.

**Composite formula:**

```
composite = (0.50 × quality) + (0.30 × timeliness) + (0.20 × communication)
```

**Why these weights:**
- Quality (50%): The work itself matters most. A late plumber who fixes the leak properly is better than a punctual one who doesn't.
- Timeliness (30%): Reliability is the second biggest predictor of repeat bookings. Customers plan their day around scheduled service.
- Communication (20%): Responsiveness matters but is less critical than outcome and reliability.

### 7.2 Rating Protections

| Protection | Purpose | Implementation |
|---|---|---|
| Double-blind submission | Prevent retaliation ratings | Neither party sees the other's review until both have submitted or 7-day window expires |
| Minimum review threshold | Prevent small-sample manipulation | Composite rating not displayed until provider has 5+ reviews |
| Recency weighting | Recent performance matters more | Ratings from last 90 days weighted 2x in composite calculation |
| Outlier detection | Identify suspicious patterns | Flag when a provider receives 3+ one-star reviews in a week (operator investigates) |
| Response right | Let providers tell their side | Providers can post a public response to any review |
| Edit window | Allow correction, prevent manipulation | Customer can edit review within 48 hours, then locked |
| Operator moderation | Remove abusive or fraudulent reviews | Operator can hide reviews with documented reason (logged in audit trail) |

### 7.3 Provider Tiers

Tiers are the long-term reputation signal. While ratings fluctuate job to job, tiers represent sustained performance over time.

**Tier requirements and benefits:**

| | Standard | Preferred | Elite |
|---|---|---|---|
| **Requirements** | Verified (all checks passed) | 10+ completed jobs, 4.5+ composite, < 5% complaint rate | 50+ completed jobs, 4.8+ composite, < 2% complaint rate |
| **Matching priority** | Base priority (score weight: 0.4) | Elevated (score weight: 0.7) | Highest (score weight: 1.0) |
| **Profile placement** | Standard listing | "Preferred" badge, featured in category results | "Elite" badge, top of results, featured on homepage |
| **Job access** | Standard jobs | Standard jobs | Standard + exclusive jobs (24-hour head start) |
| **Platform fee** | 15% | 15% | 12% |
| **Support** | Standard support | Priority support | Dedicated account manager |

**Tier evaluation:**
- Evaluated monthly based on trailing 90-day performance
- Promotion: immediate when requirements are met (no waiting period)
- Demotion: 30-day probation period when metrics drop below threshold. If metrics recover within 30 days, tier is maintained. If not, downgraded to appropriate tier.
- Demotion notification includes specific metrics that need improvement and tips for recovery

**Tier distribution (current):**

| Tier | Providers | % of Network | % of GMV |
|---|---|---|---|
| Standard | 204 | 60% | 28% |
| Preferred | 98 | 29% | 39% |
| Elite | 38 | 11% | 33% |

Elite providers represent 11% of the network but generate 33% of GMV. This validates the tier system: quality providers earn disproportionately more, which incentivizes the entire network to improve.

---

## 8. Trust Metrics

### 8.1 Trust Health Dashboard

| Metric | Current | Target | Trend |
|---|---|---|---|
| **Verification** | | | |
| Avg verification time (application → verified) | 42 hours | < 48 hours | ✅ |
| Verification pass rate | 74% | 70-80% | ✅ |
| Active providers with all credentials current | 96% | > 95% | ✅ |
| **Quality** | | | |
| Network-wide composite rating | 4.52 | > 4.5 | ✅ |
| Customer CSAT | 4.6/5.0 | > 4.5 | ✅ |
| Repeat booking rate | 58% | > 50% | ✅ |
| "Would book again" rate | 82% | > 75% | ✅ |
| **Safety** | | | |
| Dispute rate | 2.1% | < 5% | ✅ |
| Property damage claims | 0.3% | < 1% | ✅ |
| Safety incidents | 0 | 0 | ✅ |
| **Accountability** | | | |
| SLA violation rate | 4.2% | < 5% | ✅ |
| Active suspensions | 6 | Contextual | — |
| Provider churn (involuntary) | 2.8% monthly | < 5% | ✅ |

### 8.2 Trust Incidents

Every trust incident (dispute, safety report, fraud attempt, verification failure) is logged and categorized. Monthly review identifies patterns and drives policy updates.

**Trailing 12-month incident summary:**

| Category | Count | Resolution Rate | Avg Resolution Time |
|---|---|---|---|
| Service quality disputes | 89 | 98% | 3.2 days |
| No-show complaints | 23 | 100% | 1.1 days |
| Property damage claims | 12 | 100% | 5.8 days |
| Credential misrepresentation | 3 | 100% | Immediate suspension |
| Billing disputes | 18 | 94% | 2.4 days |
| Fraudulent reviews (detected) | 7 | 100% | Removed + warning |
| Safety incidents | 0 | N/A | N/A |
