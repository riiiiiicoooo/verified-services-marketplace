# Verified Services Marketplace - SLO Definitions

## SLO 1: Provider Matching Latency (Real-Time Discovery)
**Target:** 95% of service request matches return within 5 seconds
**Error Budget:** 5% of requests taking >5s per day
**Burn Rate Alert:** >50% of daily latency budget consumed in 4 hours

### Rationale
Customers browse the marketplace expecting instant provider discovery ("Find me a plumber in my area"). A 5-second latency window is tight but acceptable for complex matching (filtering 10K+ providers by location, rating, specialty, availability). The 95% target allows for occasional complex matches (requires deeper search) while ensuring 95% of requests are snappy. Longer latencies cause users to abandon the app; shorter latencies aren't feasible given the matching complexity.

### Measurement
- Count: Request latency (search → results displayed) from user action to response delivery
- Success: Results displayed in <5 seconds
- Failure: Results take >5 seconds (search timeout, query latency, network lag)
- Burn rate threshold: If >50% of daily budget in 4 hours, likely matching engine degradation or provider data overload

---

## SLO 2: Provider Availability Accuracy (Trust + Reliability)
**Target:** 95% of provider availability statuses match actual provider responsiveness
**Error Budget:** 5% of providers showing incorrect availability per week
**Burn rate Alert:** >40% of weekly accuracy budget consumed in 24 hours

### Rationale
Customers need to know if a provider is actually available for booking. Inaccurate availability (showing "available" but provider doesn't respond, or "unavailable" but they're actually free) erodes trust. The 4x throughput improvement ($15M GMV) depends on customers successfully booking available providers. A 95% accuracy target ensures most availability statuses are reliable; the 5% error budget accounts for edge cases (provider offline, network lag detecting status change).

### Measurement
- Count: Provider availability status vs. actual responsiveness (validated by booking attempts)
- Success: Provider availability matches reality (available = responds to request; unavailable = correctly unavailable)
- Failure: Availability mismatch (shown available but unresponsive; shown unavailable but responsive)
- Burn rate threshold: If >40% of weekly budget in 24 hours, check: (1) provider status polling frequency? (2) detection lag?

---

## SLO 3: Payment Escrow Safety (Financial Integrity)
**Target:** 99.99% of transactions held in escrow without loss (zero escrow failures)
**Error Budget:** 0.01% of transactions lost per year (1 in 10,000)
**Burn rate Alert:** Any escrow loss = incident

### Rationale
Payment escrow protects both customers and providers. If escrow fails (payment lost, double-charged, or stuck), trust collapses and platform faces regulatory scrutiny. A 99.99% success rate is extremely high but mandatory for payments. The 0.01% error budget (1 in 10K transactions) accounts for rare catastrophic failures (database corruption, payment processor outage). Unlike performance SLOs, escrow is asymmetric: *any* loss is a significant incident.

### Measurement
- Count: Escrow transactions that complete successfully vs. total escrow transactions
- Success: Payment held in escrow; released correctly (customer pays, provider receives)
- Failure: Escrow loss (payment lost, stuck, double-charged)
- Burn rate threshold: Any escrow failure = P1 incident; immediate escalation

---

## SLO 4: Verification Status Freshness (Compliance)
**Target:** 99% of provider verification statuses updated within 7 days of status change
**Error Budget:** 1% of verification updates delayed >7 days per week
**Burn rate Alert:** >40% of weekly freshness budget consumed in 24 hours

### Rationale
Providers' verification status (verified, unverified, banned) changes regularly. If statuses are stale, the marketplace may show unverified providers as verified (risk), or verified as unverified (user frustration). A 99% freshness target ensures almost all providers have current verification status; the 7-day window is loose enough to accommodate weekly verification batch jobs while tight enough to catch major changes (ban status) quickly.

### Measurement
- Count: Verification status update latency (change in system → display updated)
- Success: Verification status updated within 7 days
- Failure: Verification status not updated (shows stale status >7 days)
- Burn rate threshold: If >40% of weekly budget in 24 hours, check verification job lag

---

## SLO 5: Matching Throughput (GMV Growth)
**Target:** 99% of incoming requests are processed (not dropped/rejected)
**Error Budget:** 1% of requests rejected per day
**Burn rate Alert:** >50% of daily throughput budget consumed in 4 hours

### Rationale
The 4x throughput improvement depends on handling request volume. Dropped requests (rate-limited, queue overflowed, service down) directly reduce GMV. A 99% success rate ensures almost all customer requests are processed; the 1% error budget allows for occasional overload. Missing this SLO directly impacts revenue.

### Measurement
- Count: Requests successfully processed vs. total requests received
- Success: Request processed (match attempted)
- Failure: Request dropped/rejected (rate limit, timeout, service unavailable)
- Burn rate threshold: If >50% of daily budget in 4 hours, scale matching service

---

## Error Budget Governance
- **Review Cadence:** Daily check on matching latency and throughput; weekly check on provider availability and verification freshness
- **Escalation:** If matching latency >5s for >50% of requests, investigate provider data quality or search optimization
- **Provider availability:** Weekly audit of provider responsiveness; update status polling if accuracy <95%
- **Payment escrow:** Zero tolerance for any escrow issues; any loss triggers immediate postmortem
- **Feature freeze:** If throughput drops <98%, pause non-critical features; focus on capacity

