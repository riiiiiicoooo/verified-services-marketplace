# Source Code: Reference Implementation

> **Note:** This code is a PM-authored reference implementation demonstrating the core technical concepts behind the Verified Services Marketplace. It is not production code. These prototypes were built to validate feasibility, communicate architecture to engineering, and demonstrate technical fluency during product development.

## Contents

| File | Purpose |
|---|---|
| `matching/matching_engine.py` | Provider-job matching algorithm: PostGIS radius filtering, composite scoring, capacity management |
| `verification/provider_verifier.py` | Automated verification pipeline: Checkr integration, license validation, insurance parsing, expiration monitoring |
| `payments/escrow_manager.py` | Stripe Connect escrow workflow: hold creation, capture on completion, refunds, provider payouts |
| `ratings/review_system.py` | Weighted composite rating engine: double-blind reviews, tier evaluation, anti-gaming protections |
| `analytics/marketplace_health.py` | Marketplace health metrics: liquidity scoring, Gini coefficient, health index calculation |

## How These Were Used

As PM, I wrote these prototypes to:

1. **Validate the matching algorithm** — tested composite scoring weights against historical job completion data to find the right balance of rating, completion rate, response time, and tier
2. **Spec the payment flow** — mapped every Stripe Connect API call for escrow, capture, and refund to ensure the PRD requirements were technically feasible
3. **Prove PostGIS performance** — benchmarked radius queries against 1,000 provider records to confirm < 50ms latency before committing to the architecture
4. **Model marketplace economics** — built the health index and Gini calculations to give the operator team a single dashboard view of marketplace status
5. **Communicate with engineering** — working code conveys intent more precisely than requirements documents alone
