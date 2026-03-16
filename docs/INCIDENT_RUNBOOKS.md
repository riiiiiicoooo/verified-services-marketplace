# Verified Services Marketplace - Incident Runbooks

---

## Incident 1: Payment Escrow Failure (Stuck Transaction)

### Context
On March 15 at 3 PM, a customer books a $1,200 home renovation service. Payment is charged to the customer's card and should be held in escrow pending service completion. However, the escrow backend fails midway through (database connection timeout). The payment is taken from customer; the provider doesn't see the booking. Customer and provider are both angry; payment is stuck in limbo.

### Detection
- **Alert:** Escrow transaction takes >30 seconds OR status is "PENDING" for >1 hour
- **Symptoms:**
  - Customer sees "Payment processing" but transaction never completes
  - Provider doesn't see booking in their queue
  - Payment processor shows charge successful, but marketplace shows "pending"

### Diagnosis (10 minutes)

**Step 1: Verify the stuck transaction**
```sql
-- Find stuck escrow transaction
SELECT
  transaction_id,
  customer_id,
  provider_id,
  amount,
  status,
  created_at,
  updated_at,
  error_message
FROM escrow_transactions
WHERE status = 'PENDING'
  AND created_at < NOW() - INTERVAL 30 MINUTES
  AND created_at > NOW() - INTERVAL 2 HOURS;

-- Result:
-- transaction_id: escrow_20260315_001234
-- status: PENDING (stuck for 45 minutes)
-- error_message: "Database connection timeout during escrow commit"
```

**Step 2: Check payment processor**
```bash
# Verify payment was charged to customer
curl -X GET https://payment-processor.com/v1/charges/charge_abc123 \
  -H "Authorization: Bearer $API_KEY"

# Result: Charge successful, $1,200 deducted from customer account
# But marketplace escrow record not created (DB connection failed before insert)
```

**Step 3: Assess impact**
```sql
-- Find all stuck transactions in past 2 hours
SELECT COUNT(*) as stuck_count, SUM(amount) as total_stuck_amount
FROM escrow_transactions
WHERE status = 'PENDING'
  AND created_at > NOW() - INTERVAL 2 HOURS;

-- Result: 3 stuck transactions, $3,500 total stuck
```

### Remediation

**Immediate (0-5 min): Restore stuck transaction**
```sql
-- Manually create escrow record (recovery action)
INSERT INTO escrow_transactions (
  transaction_id,
  customer_id,
  provider_id,
  amount,
  status,
  created_at
) VALUES (
  'escrow_20260315_001234',
  'cust_xyz',
  'prov_abc',
  1200.00,
  'FUNDED',  -- Mark as funded (payment already charged)
  NOW()
);

-- Update booking to reflect escrow is funded
UPDATE bookings
SET escrow_transaction_id = 'escrow_20260315_001234',
    status = 'CONFIRMED'
WHERE id = 'booking_xyz';

-- Notify provider that booking is confirmed
send_notification(
  provider_id='prov_abc',
  message='Your booking is confirmed; escrow is funded. Service amount: $1,200'
);

-- Notify customer that payment is secured
send_notification(
  customer_id='cust_xyz',
  message='Your payment of $1,200 is secured in escrow. Service begins on [DATE].'
);
```

**Short-term (5-30 min): Fix database connection issue**
```bash
# Check database connectivity
SHOW REPLICA CONNECTIVITY;
# Result: Replica lag 30 seconds (database under load)

# Add connection pool capacity
kubectl set env deployment/escrow-service \
  DB_CONNECTION_POOL_SIZE=200 \
  (was 50; increased 4x)

# Restart escrow service
kubectl rollout restart deployment/escrow-service
```

**Root cause remediation (30 min - 1 hour):**

1. **Improve escrow transaction robustness:**
   ```python
   @transaction
   def create_escrow(booking):
       try:
           # 1. Charge customer (via payment processor)
           charge = payment_processor.charge(
               customer=booking.customer,
               amount=booking.amount,
               idempotency_key=booking.id  # Idempotent; safe to retry
           )

           # 2. Create escrow record (atomic with charge)
           escrow = EscrowTransaction.create(
               transaction_id=charge.id,
               customer_id=booking.customer.id,
               provider_id=booking.provider.id,
               amount=booking.amount,
               status='FUNDED'
           )

           # 3. Update booking
           booking.update(escrow_id=escrow.id, status='CONFIRMED')

       except DatabaseError as e:
           # If escrow record creation fails, charge is already deducted
           # Retry logic: Try again; if it fails 3x, escalate to support
           retry_create_escrow_with_backoff(booking, charge)

       return escrow
   ```

2. **Add idempotency to escrow operations:**
   ```python
   # Every escrow operation uses idempotency key (safe to retry)
   # If request fails, retry with same key → payment processor returns cached result
   charge = payment_processor.charge(
       customer=customer,
       amount=amount,
       idempotency_key=booking_id  # Unique key; prevents double-charging
   )
   ```

3. **Implement escrow health monitoring:**
   ```python
   def monitor_escrow_health():
       # Check for PENDING transactions >10 minutes old
       stuck = EscrowTransaction.filter(
           status='PENDING',
           created_at__lt=now() - timedelta(minutes=10)
       )

       if stuck.exists():
           alert.critical(f"Stuck escrow transactions detected: {len(stuck)}")
           # Attempt recovery: retry commit
           for escrow in stuck:
               try:
                   complete_escrow_fund(escrow)
               except Exception:
                   escalate_to_support(escrow)
   ```

4. **Add database connection resilience:**
   ```python
   # Use connection pooling + circuit breaker
   db_pool = connection_pool.create(
       min_size=50,
       max_size=200,
       timeout=5,  # Connection timeout
       retry_attempts=3,
       retry_delay=0.5  # 500ms backoff
   )

   # If connections exceed max_size, queue requests instead of failing
   @circuit_breaker(failure_threshold=5, recovery_timeout=60)
   def create_escrow(booking):
       with db_pool.get_connection() as conn:
           return conn.execute(escrow_insert_query)
   ```

### Communication Template

**Internal (Slack #incidents)**
```
VERIFIED SERVICES INCIDENT: Escrow Transaction Stuck
Severity: P1 (Financial Impact - Customer charged, no service funded)
Duration: 3:00-3:45 PM UTC (45 min)
Affected: 3 transactions, $3,500 stuck

Root Cause: Database connection timeout during escrow commit. Payment charged from customer; escrow record not created.

Actions:
1. Manually created escrow records for 3 stuck transactions
2. Notified customers and providers of status
3. Increased database connection pool (50 → 200)
4. Implemented idempotency keys to prevent double-charging on retry
5. Added monitoring for stuck escrow transactions >10 min old

Resolution: All stuck transactions recovered; escrow records created.

ETA: Monitoring deployed by 16:00 UTC
Assigned to: [PAYMENTS_SPECIALIST], [DBA]
```

**Customer Email**
```
Subject: Payment Update - Your Service Booking

We've resolved an issue with your recent $1,200 service booking. Your payment has been successfully secured in escrow.

Status: Service confirmed and ready to begin on [DATE]

Your payment is safe. It will be released to the service provider upon service completion.

If you have any questions, please contact support.

Regards,
The Marketplace Team
```

### Postmortem Questions
1. Why did database connection pool size default to 50?
2. Should we test escrow creation under load (stress testing)?
3. Can we implement automatic stuck transaction recovery?

---

## Incident 2: Matching Latency Spike (Service Search Timeout)

### Context
On March 16 at 10:00 AM, customers report that searching for services (plumbers, electricians, etc.) takes 10-15 seconds instead of the usual 2-3 seconds. Search requests are timing out at 30 seconds. The search index (Elasticsearch) is overloaded. Peak time during business hours exacerbates the problem. Customers are abandoning search; conversion drops 40%.

### Detection
- **Alert:** Search latency p95 >3s OR error rate >2% on search requests
- **Symptoms:**
  - Search requests return 503 Gateway Timeout
  - Elasticsearch cluster CPU at 100%
  - Customer complaints: "Search is stuck"

### Diagnosis (10 minutes)

**Step 1: Check Elasticsearch health**
```bash
# Check cluster status
curl -X GET http://elasticsearch:9200/_cluster/health

# Result: status=yellow, 2/3 shards active (1 shard down)

# Check disk usage
curl -X GET http://elasticsearch:9200/_cat/nodes?v

# Result: Node 2 disk full (100% used); shard couldn't allocate
```

**Step 2: Identify bottleneck**
```bash
# Monitor search query performance
curl -X GET http://elasticsearch:9200/_stats/search

# Result: 500 searches/sec (peak load)
# Avg query latency: 8 seconds (unacceptable)

# Check hot shards
curl -X GET http://elasticsearch:9200/_cat/shards?v | grep INITIALIZING

# Result: Provider shard initializing (hasn't finished allocation)
```

**Step 3: Check provider data size**
```
Current providers: 12,000
Elasticsearch index size: 8 GB
Queries per second: 500 (peak)

At current scale, single Elasticsearch cluster is at capacity.
With 2x providers incoming (24K), single cluster insufficient.
```

### Remediation

**Immediate (0-5 min): Shed load**
```bash
# Temporarily reduce provider result set
# Return top 10 providers instead of top 50
ELASTICSEARCH_RESULT_LIMIT=10  # was 50

# Enable caching for popular searches
SEARCH_CACHE_TTL=300  # Cache results for 5 minutes

# Rate-limit aggressive users
RATE_LIMIT_PER_USER=10_requests_per_minute  # was unlimited
```

**Short-term (5-30 min): Add capacity**
```bash
# Add 2 more Elasticsearch nodes (was 1 node; now 3 nodes)
kubectl scale deployment elasticsearch --replicas=3

# Rebalance shards
curl -X POST http://elasticsearch:9200/_cluster/reroute?retry_failed=true

# Enable shard awareness (distribute shards across nodes)
```

**Root cause remediation (30 min - 1 hour):**

1. **Implement read replicas for Elasticsearch:**
   ```bash
   # Add dedicated read nodes (don't participate in shard selection, just answer queries)
   # Write to master nodes; read from read nodes
   ```

2. **Optimize Elasticsearch queries:**
   ```python
   # OLD: Search all 12K providers, sort by rating
   # Cost: 12K docs scanned, sorted by rating (slow)
   GET /providers/_search
   {
       "query": {"match": {"category": "plumber"}},
       "sort": [{"rating": "desc"}]
   }

   # NEW: Pre-aggregate by rating tier; search narrow tier first
   GET /providers/_search
   {
       "query": {
           "bool": {
               "must": [{"match": {"category": "plumber"}}],
               "filter": [{"range": {"rating": {"gte": 4.5}}}]  # Filter for high-rated only
           }
       },
       "size": 10  # Return only top 10
   }
   # Cost: <100 docs scanned, no sorting (fast)
   ```

3. **Implement caching for popular searches:**
   ```python
   # Cache search results for common queries
   @cache(ttl=300)  # Cache for 5 minutes
   def search_providers(category, location):
       return elasticsearch.search(...)

   # Expected cache hit rate: 60-70% (most searches are for common categories)
   # Reduces load on Elasticsearch by 60-70%
   ```

4. **Add monitoring for Elasticsearch capacity:**
   ```python
   def monitor_elasticsearch_capacity():
       stats = es.cluster.health()

       if stats['active_shards_percent'] < 100:
           alert.warn("Elasticsearch shards not healthy")

       if stats['active_shards'] < expected_shard_count:
           alert.error("Elasticsearch shard missing; cluster degraded")

       # Monitor query latency
       if query_latency_p95 > 3:
           alert.warn("Elasticsearch query latency high")
   ```

### Communication Template

**Internal (Slack #incidents)**
```
VERIFIED SERVICES INCIDENT: Search Latency Spike
Severity: P2 (Conversion Impact - 40% drop in conversions)
Duration: 10:00-10:45 AM UTC (45 min)
Affected: Search service; customers abandoning searches

Root Cause: Elasticsearch single node at capacity (disk full, 500 queries/sec overload). Shard reallocation stalled.

Actions:
1. Temporarily reduced result set (50 → 10 providers) to shed load
2. Enabled search result caching (TTL 5 min)
3. Scaled Elasticsearch from 1 → 3 nodes
4. Rebalanced shards across nodes
5. Optimized queries to filter high-rated providers first (reduce scans)

Resolution: Search latency returned to <2s by 10:45 AM UTC.

ETA: Multi-node Elasticsearch deployment validated by 11:30 UTC
Assigned to: [BACKEND_ENGINEER], [DEVOPS]
```

**User Notification (In-app banner)**
```
Performance Update

We've optimized our search engine to provide faster results. Try searching for a service now!
```

### Postmortem Questions
1. Why was Elasticsearch running on single node?
2. Should we monitor Elasticsearch disk usage and alert at 80%?
3. Can we implement auto-scaling for Elasticsearch?

---

## Incident 3: Provider Availability Status Mismatch (Trust Erosion)

### Context
A customer searches for plumbers and sees "Tom's Plumbing" marked as "Available for booking." Customer books a $600 job. However, Tom is actually out of service (left the platform, but his status wasn't updated). Customer payment is taken; booking fails when system tries to confirm with Tom. Customer is charged but can't contact the provider.

### Detection
- **Alert:** Provider availability status matches <90% with actual responsiveness
- **Symptoms:**
  - Customer books unavailable provider
  - Booking creation fails (provider not responding)
  - Customer complaints: "Provider isn't responding to my request"

### Diagnosis (20 minutes)

**Step 1: Validate availability mismatch**
```sql
-- Find providers marked available but unresponsive
SELECT
  provider_id,
  provider_name,
  status_in_system,
  last_availability_update,
  last_booking_attempt,
  booking_acceptance_rate_last_7d
FROM provider_availability_audit
WHERE status_in_system = 'AVAILABLE'
  AND booking_acceptance_rate_last_7d < 0.5  -- <50% booking acceptance = unresponsive
  AND last_availability_update < NOW() - INTERVAL 24 HOURS;

-- Result: Tom's Plumbing marked AVAILABLE, but 0% booking acceptance (0/5 bookings)
```

**Step 2: Identify root cause**
```
Tom's last availability update: March 14 (2 days ago)
Tom's last booking response: March 13 (3 days ago)
Tom's booking acceptance rate: 0% (0 accepted out of 5 requests)

Why status didn't update:
- Availability polling happens every 4 hours
- Tom didn't manually mark himself unavailable
- System couldn't detect that Tom quit the platform (no explicit signal)
```

**Step 3: Check for similar cases**
```sql
-- Find all providers with availability mismatches
SELECT
  COUNT(*) as mismatch_count,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM providers), 2) as pct_affected
FROM provider_availability_audit
WHERE status_in_system = 'AVAILABLE'
  AND booking_acceptance_rate_last_7d < 0.3;  -- <30% acceptance

-- Result: 45 providers (0.4%) have availability mismatches
```

### Remediation

**Immediate (0-10 min): Mark Tom as unavailable**
```sql
-- Manually mark provider as unavailable
UPDATE providers
SET status = 'UNAVAILABLE',
    status_reason = 'Auto-marked: Response rate <10% on recent bookings',
    updated_at = NOW()
WHERE id = 'provider_tom_plumbing';

-- Refund customer for stuck booking
UPDATE transactions
SET status = 'REFUNDED',
    refund_date = NOW()
WHERE booking_id = 'booking_xyz'
  AND status = 'PENDING';

-- Notify customer
send_notification(
  customer_id='cust_xyz',
  subject='Booking Canceled - Full Refund',
  message='Your booking for Tom\'s Plumbing was cancelled. Your $600 payment has been fully refunded.'
);

-- Notify Tom (to investigate)
send_notification(
  provider_id='provider_tom_plumbing',
  subject='Your Account Status Changed',
  message='Your availability status was automatically marked UNAVAILABLE due to low response rate. Please log in to update your status.'
);
```

**Short-term (10-30 min): Improve availability detection**
```bash
# Temporarily increase polling frequency (4h → 30 min) for providers with low response rates
# THIS INCREASES API LOAD - only for monitoring, not permanent solution

# Identify providers with <50% acceptance rate
kubectl exec -it pod/provider-status-monitor -- \
  python -m provider_status.identify_unresponsive --acceptance_threshold=0.5

# Increase polling frequency for these providers
UPDATE provider_polling_config
SET polling_interval_minutes = 30
WHERE provider_id IN (SELECT id FROM providers WHERE acceptance_rate < 0.5);
```

**Root cause remediation (1-2 hours):**

1. **Implement automatic availability detection:**
   ```python
   def update_provider_availability_based_on_behavior():
       # Don't rely on manual status updates or infrequent polling
       # Use booking response behavior as truth signal

       for provider in get_all_providers():
           recent_bookings = get_bookings(provider, last_7_days=True)
           acceptance_rate = sum(b.accepted for b in recent_bookings) / len(recent_bookings)

           if acceptance_rate < 0.1:  # <10% acceptance = mark unavailable
               provider.mark_unavailable(reason="Low booking acceptance rate")
               notify_provider("Your account marked unavailable; please verify your status")

           if acceptance_rate > 0.8:  # >80% acceptance = mark available
               provider.mark_available()
   ```

2. **Implement booking timeout + auto-unavailable:**
   ```python
   def handle_booking_timeout():
       # If provider doesn't respond to booking in 30 minutes → mark temporarily unavailable

       stuck_bookings = get_bookings(status='WAITING_FOR_PROVIDER_RESPONSE')

       for booking in stuck_bookings:
           if booking.created_at < now() - timedelta(minutes=30):
               # Provider didn't respond; temporarily mark unavailable
               provider = booking.provider
               provider.mark_unavailable_temporarily(duration_hours=4)

               # Refund customer
               booking.refund_customer()
               notify_customer("Provider didn't respond; your booking cancelled with full refund")
   ```

3. **Add real-time availability sync:**
   ```python
   # Instead of polling every 4 hours, use webhooks
   # When provider status changes → webhook sent to platform immediately

   @webhook_endpoint('/provider-status-changed')
   def handle_provider_status_change(event):
       provider_id = event['provider_id']
       new_status = event['status']  # 'online', 'offline', 'unavailable'

       update_provider_status(provider_id, new_status)
       notify_customers_of_status_change(provider_id, new_status)
   ```

4. **Improve provider onboarding verification:**
   ```python
   # Require providers to periodically re-verify they're still active
   # If no re-verification in 30 days → mark as stale

   def check_provider_verification_freshness():
       stale_providers = get_providers(
           last_verification_date < now() - timedelta(days=30)
       )

       for provider in stale_providers:
           # Send verification challenge
           send_verification_email(
               provider,
               subject="Please re-verify your status",
               action="Click here to confirm you're still active"
           )

           # If no response in 7 days → mark unavailable
   ```

### Communication Template

**Internal (Slack #incidents)**
```
VERIFIED SERVICES INCIDENT: Provider Availability Mismatch
Severity: P2 (Trust Impact - Customer booked unavailable provider)
Duration: March 14-16; discovered via customer complaint
Affected: 45 providers (0.4%) with <30% booking acceptance

Root Cause: Availability status polling every 4 hours is too infrequent. No auto-detection of unresponsive providers. Tom marked available but didn't respond to bookings for 3 days.

Actions:
1. Manually marked Tom and 44 other unresponsive providers as UNAVAILABLE
2. Refunded customer's $600 (stuck booking)
3. Implemented auto-unavailable based on booking acceptance rate (<10% triggers)
4. Added real-time availability sync via webhooks (vs. polling)
5. Implemented booking timeout + auto-refund (30 min no response → refund)

Resolution: All unresponsive providers marked; customer refunded.

ETA: Availability detection improvements deployed by 14:00 UTC
Assigned to: [BACKEND_ENGINEER], [PRODUCT_MANAGER]
```

**Customer Email**
```
Subject: Your Booking Refund - $600

Your booking with Tom's Plumbing has been cancelled due to provider unavailability.

Your payment of $600 has been fully refunded to your original payment method (may take 1-2 business days to appear).

We've improved our provider availability checks to prevent this in the future. You can try booking another provider now.

We apologize for the inconvenience.

Regards,
The Marketplace Team
```

### Postmortem Questions
1. Why was provider availability polling at 4-hour intervals?
2. Should we use behavioral signals (booking acceptance rate) instead of status flags?
3. Can we implement instant provider status updates?

---

## General Escalation Path
1. **P3 (Slow search, provider lag):** Assign to engineer; investigate
2. **P2 (Matching latency >5s, availability issues):** Escalate to backend lead + product within 15 min
3. **P1 (Payment escrow loss, widespread matching failure):** Page payments specialist + VP engineering immediately
4. **All payment escrow incidents:** Zero tolerance; immediate escalation + postmortem

