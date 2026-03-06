# Architecture Decision Records

Significant technical decisions made during the design and implementation of the Verified Services Marketplace. Each ADR captures the context, alternatives, and trade-offs behind a decision.

---

## ADR-001: State Machine Verification Pipeline with Parallel Check Execution

**Status:** Accepted
**Date:** 2024-12
**Context:** Provider onboarding requires three independent verification steps -- criminal background check (Checkr), trade license validation (state licensing board APIs), and insurance certificate validation (ACORD form parsing). Background checks take 24-72 hours via webhook callback, while license and insurance checks can complete synchronously in some cases. A strictly sequential pipeline would add days to onboarding time. We needed a design that minimizes total verification latency while still enforcing ordering constraints (e.g., a failed background check should not waste effort on downstream checks).
**Decision:** Implement a state machine (`VerificationPipeline`) that models each verification step as a discrete state (`pending`, `bg_check_pending`, `license_pending`, `insurance_pending`, `onboarded`, `rejected`). The orchestrator (`ProviderVerifier.start_verification`) kicks off the Checkr background check asynchronously via webhook and runs license and insurance checks in parallel. The Trigger.dev job (`provider_onboarding.ts`) serializes steps that have data dependencies (Checkr candidate creation before report creation) but runs license and insurance verification concurrently after the background check passes. A fail-fast policy rejects the application on any blocking failure without waiting for remaining checks.
**Alternatives Considered:**
- Fully sequential pipeline (background, then license, then insurance): Simpler but adds 24-72 hours of unnecessary wait time since license and insurance checks are independent.
- Fully parallel with reconciliation: All three checks fire simultaneously and a reconciliation step evaluates results. Rejected because a failed background check is an absolute disqualifier, and running license/insurance checks for a provider who will be rejected wastes API calls and operator time.
- Event-driven saga with compensating transactions: More resilient to partial failures but significantly more complex for a three-step pipeline with clear ordering.
**Consequences:** Average onboarding time is approximately 42 hours (dominated by Checkr's 24-48 hour turnaround). License and insurance checks add no additional calendar time when run in parallel. The state machine enables idempotent retries and clear audit trails. However, the Trigger.dev polling approach (checking Checkr every 60 seconds for up to 7 days) is wasteful compared to pure webhook-driven completion; a production system should prefer webhook callbacks with polling as a fallback.

---

## ADR-002: Checkr for Background Checks with Individualized Assessment Policy

**Status:** Accepted
**Date:** 2024-12
**Context:** The marketplace connects providers who enter customers' homes. Criminal background checks are a non-negotiable trust requirement, but the implementation must comply with the Fair Credit Reporting Act (FCRA) and follow EEOC guidance on fair-chance hiring. A binary pass/fail approach risks legal liability under Ban-the-Box legislation in many states, while a fully manual review process does not scale.
**Decision:** Use Checkr as the sole background check vendor. Implement a two-tier adjudication policy: (1) automatic disqualification for a defined set of offenses -- violent felonies (no time limit), sex offenses (no time limit), felony fraud/theft within 7 years, and active warrants/pending felony charges (see `AUTO_DISQUALIFY_OFFENSES` in `provider_verifier.py`); and (2) individualized assessment routed to an operator manual review queue for records that are not auto-disqualifying (e.g., misdemeanors, older felonies). Checkr's "clear" result maps to `PASSED`, "consider" with auto-disqualifying offenses maps to `FAILED`, and "consider" without auto-disqualifying offenses maps to `REQUIRES_MANUAL`.
**Alternatives Considered:**
- Multiple background check vendors (Checkr + Sterling + GoodHire): Provides redundancy and potentially broader coverage, but increases integration complexity and cost. Checkr's API is the most developer-friendly and covers the required check types (SSN trace, county/state/federal criminal, sex offender registry).
- Binary pass/fail without individualized assessment: Simpler to implement but exposes the platform to legal risk under FCRA adverse action requirements and EEOC disparate impact guidance.
- No background checks (rely on reviews/ratings only): Unacceptable given the in-home service context.
**Consequences:** The individualized assessment path requires operator staffing for manual review, which does not scale linearly. The `handle_checkr_webhook` method must verify the `X-Checkr-Signature` HMAC header in production (noted in code comments but not implemented in the reference). FCRA compliance requires implementing adverse action notice workflows (pre-adverse notice, waiting period, final adverse action with dispute rights) when a check results in rejection.

---

## ADR-003: Dual-Path License Validation (API + Manual Fallback)

**Status:** Accepted
**Date:** 2024-12
**Context:** Trade license validation must verify that a provider holds an active, non-revoked license in the correct state for their service category. The United States has no unified licensing system; each state operates its own licensing board with varying levels of API access. At the time of implementation, 34 states offer some form of electronic lookup API, while the remaining states require manual verification (visiting the state website or calling the board).
**Decision:** Maintain a registry of states with API access (`STATES_WITH_LICENSE_API` in `provider_verifier.py`, covering 34 states). For states in the registry, call the state licensing board API via per-state adapters (planned `state_apis/` directory) to validate license existence, active status, holder name match, type match, and expiration (must be >30 days from now). For states not in the registry, route the verification to `REQUIRES_MANUAL` status with operator queue assignment. The `_api_license_lookup` method validates four criteria: license exists and is active, license type matches service category, holder name matches provider, and expiration date is more than 30 days out.
**Alternatives Considered:**
- Third-party license verification aggregator (e.g., LicenseLogic, Verifiable): Simplifies integration to a single API but adds per-verification cost ($5-15 per lookup), vendor lock-in, and a dependency on the aggregator's state coverage.
- Manual-only verification for all states: Consistent process but does not scale and adds 1-3 business days to every verification.
- Trust provider-submitted license numbers without verification: Unacceptable -- fraudulent license claims are a significant risk vector.
**Consequences:** The dual-path approach requires maintaining per-state API adapters as states add, change, or deprecate their APIs. The 34-state API coverage handles approximately 85% of provider applications automatically. The manual fallback creates a backlog that requires operator capacity planning. Cross-state licensing edge cases (provider licensed in State A but serving in State B) are routed to manual review via `handle_wrong_state_license`.

---

## ADR-004: ACORD Form Parsing for Insurance Certificate Validation

**Status:** Accepted
**Date:** 2024-12
**Context:** Providers must carry general liability insurance with a minimum coverage of $1M per occurrence. Insurance certificates in the U.S. are standardized on ACORD forms (ACORD 25 for general liability, ACORD 28 for property). The platform needs to extract carrier name, policy number, coverage limits, named insured, and expiration date from uploaded certificates, and validate against minimum coverage requirements (`INSURANCE_MINIMUMS` in `provider_verifier.py`).
**Decision:** Accept ACORD 25/28 form uploads and extract structured data using OCR with field-position mapping. ACORD forms have standardized field positions, making extraction reliable compared to free-form documents. Validate extracted data against defined minimums: general liability >= $1M per occurrence, workers' comp at state minimum (if applicable), commercial auto >= $500K (if applicable). Certificates expiring within 30 days are rejected with a request to upload renewed certificates. The `parse_acord_certificate` method extracts carrier, AM Best rating, policy number, coverage limits, effective/expiration dates, and additional insured status.
**Alternatives Considered:**
- Integration with insurance verification APIs (e.g., ACORD/Ivans, Verisk): Provides real-time policy status verification directly from carriers, but these APIs have limited carrier coverage, high per-query costs, and complex onboarding requirements.
- Manual operator review of all certificates: Accurate but does not scale and introduces human error in reading coverage amounts.
- Accept provider-entered insurance information without document verification: Too easy to falsify.
**Consequences:** OCR accuracy depends on document quality. Scanned/photographed certificates may have lower extraction accuracy than digitally-generated PDFs. The system should implement confidence scoring and route low-confidence extractions to manual review. Insurance certificates are point-in-time documents; a policy can be cancelled after the certificate is issued. The credential expiration monitoring system (ADR-005) partially addresses this, but real-time policy status verification would require carrier API integration.

---

## ADR-005: Tiered Credential Expiration Monitoring with Escalating Notifications

**Status:** Accepted
**Date:** 2024-12
**Context:** Provider credentials (trade licenses, insurance certificates) have expiration dates. An expired credential means the provider is operating without required qualifications or coverage, which is both a trust violation and a liability risk. The platform needs a system that proactively alerts providers before expiration and automatically suspends providers who fail to renew.
**Decision:** Implement a daily cron job (`check_expiring_credentials`) that queries verifications with `status = 'passed'` and `expires_at` within a configurable window. Use tiered escalation with increasing notification urgency: 30 days out (email only), 14 days out (email + SMS), 7 days out (email + SMS + push + in-app alert + operator notification). At expiration, start a 14-day grace period during which the provider remains active but receives daily reminders. After the grace period, auto-suspend the provider (`is_active = false`). The database schema supports this with `reminder_30d_sent`, `reminder_14d_sent`, and `reminder_7d_sent` boolean columns on the `verifications` table, and `suspended_at`/`suspended_reason` columns on the `providers` table. The `idx_verifications_expiry` partial index on `(expires_at, status) WHERE status = 'passed'` ensures the daily query is efficient.
**Alternatives Considered:**
- Single notification at expiration with immediate suspension: Too aggressive; providers need lead time to renew credentials, which can take weeks for some state licensing boards.
- No auto-suspension (notification only): Insufficient; providers may ignore notifications, and the platform carries liability for allowing unverified providers to operate.
- Real-time monitoring via carrier/board webhooks: Ideal but not available for most state licensing boards or insurance carriers.
**Consequences:** The tiered approach balances provider experience (adequate renewal notice) with platform safety (guaranteed suspension of lapsed credentials). The 14-day grace period is a trade-off: it keeps providers earning while they renew, but it means the platform temporarily allows providers with expired credentials. The daily cron frequency is sufficient for license/insurance expiration (which is date-granular, not time-granular) but would need to be more frequent for time-sensitive credentials.

---

## ADR-006: Weighted Composite Scoring for Provider-Job Matching with PostGIS Spatial Filtering

**Status:** Accepted
**Date:** 2024-12
**Context:** The matching engine must find and rank verified providers for each service request. The two key challenges are spatial filtering (finding providers within a radius of the job location) and ranking (determining which providers to notify first from the candidate set). The ranking algorithm must balance multiple signals -- rating quality, reliability, responsiveness, and verification tier -- while avoiding winner-take-all dynamics where top-rated providers monopolize all jobs.
**Decision:** Implement a two-stage pipeline: (1) FILTER using PostGIS `ST_DWithin` with a GIST index on `provider.service_location` to find providers within the requested radius who are verified, active, serve the requested category, and have available capacity; (2) RANK using a weighted composite score with five components: rating (0.35 weight, normalized 0-1 from composite rating), completion rate (0.25, direct percentage), response time (0.20, inverse scoring where <1 hour = 1.0), tier (0.15, Elite=1.0/Preferred=0.7/Standard=0.4), and recency (0.05, how recently active). Notify top 10 matched providers. A `provider_availability` materialized view pre-computes available capacity (`max_concurrent_jobs - active_jobs`) to avoid expensive joins at query time. Matching performance target: <3 seconds end-to-end (actual ~200ms).
**Alternatives Considered:**
- Simple distance-based matching (nearest provider wins): Ignores quality signals and leads to poor customer outcomes.
- ML-based ranking model: More sophisticated but requires training data that does not exist at launch. The weighted composite approach provides a transparent, explainable baseline that can be replaced with ML later (the `new_search_algorithm` feature flag in LaunchDarkly is already set up for this A/B test).
- Round-robin matching to enforce fairness: Guarantees equal distribution but ignores quality differentiation, which undermines the tier system and the incentive for providers to earn higher ratings.
**Consequences:** The weight distribution (rating=0.35, completion=0.25, response=0.20, tier=0.15, recency=0.05) heavily favors proven quality, which may disadvantage new providers. The 0.05 recency weight and 0.5 neutral score for providers with no data partially mitigate cold-start bias. The Gini coefficient monitoring in `marketplace_health.py` serves as a guardrail against earnings concentration (target range 0.30-0.45). If the Gini exceeds 0.55, the system recommends interventions like "new provider boost" in matching. The materialized view requires periodic refresh (`REFRESH MATERIALIZED VIEW CONCURRENTLY provider_availability`), adding operational complexity.
