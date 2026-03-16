# Verified Services Marketplace - Capacity Plan

## Executive Summary
Verified Services Marketplace connects customers with verified service providers. This plan quantifies infrastructure and team capacity for current state, 2x growth, and 10x growth scenarios.

---

## Current State (Q1 2026)

### Usage Metrics
- **Active Providers:** 12,000
- **Active Customers:** 45,000
- **Transactions/Day:** 2,100 ($15M annualized GMV)
- **Matching Requests/Day:** 18,000 (8.5 per customer average)
- **Average Transaction Value:** $350
- **Provider Availability Polling Frequency:** Every 4 hours
- **Peak Throughput:** 80 requests/minute (18K/day ÷ 5 business hours)

### Infrastructure
| Component | Current | Monthly Cost |
|-----------|---------|--------------|
| **Matching Service** | 3 × t3.xlarge (request processing) | $432 |
| **Payment Processing** | PCI-compliant, payment processor integrated | $8,500 |
| **Provider Database** | db.r5.xlarge (12K providers + history) | $2,800 |
| **Search Index** | Elasticsearch cluster (provider search) | $1,200 |
| **Cache (hot providers)** | 8 GB Redis | $720 |
| **Message Queue (bookings)** | RabbitMQ 3-node | $900 |
| **Monitoring/Logging** | CloudWatch + DataDog | $600 |
| **Customer/Transaction Storage** | PostgreSQL + S3 | $1,000 |
| **Total Monthly** | | **$16,152** |

### Team Capacity
| Role | Count | Utilization |
|------|-------|-------------|
| **Backend Engineers** | 3 | 85% |
| **Payments Specialist** | 1 | 80% |
| **Data Analyst** | 1 | 70% |
| **SRE/DevOps** | 1 | 75% |
| **Product Manager** | 1 | 90% |

---

## 2x Growth Scenario (12 months forward)
**Assumption:** 24K providers, 90K customers, 4,200 transactions/day, 36K requests/day, peak 160 req/min

### What Breaks First
1. **Matching Service Throughput:** Single cluster can't handle 160 req/min peak; requests queue, latency >5s
2. **Provider Availability Polling:** 24K providers polled every 4 hours = 6K polls/hour; API rate limits exceeded
3. **Search Index Latency:** Elasticsearch becomes slow with 24K providers + 100K historical records
4. **Payment Processing Volume:** Processor throughput limit at 50 TPS; exceeding capacity during peak hours
5. **Team Capacity:** 3 backend engineers can't maintain 2x feature velocity; on-call burnout

### Required Infrastructure Changes
| Component | Current → 2x | Incremental Cost |
|-----------|--------------|-----------------|
| **Matching Service** | 3 × t3.xlarge → 6 × t3.2xlarge (auto-scale peak) | +$864/month |
| **Payment Processing** | Upgrade to higher-tier processor plan | +$4,000/month |
| **Provider Database** | r5.xlarge → r6i.2xlarge + 1 read replica | +$3,200/month |
| **Search Index** | Single cluster → 2-node Elasticsearch cluster | +$600/month |
| **Provider Status Cache** | 8 GB → 15 GB Redis + provider status streaming | +$450/month |
| **Message Queue** | RabbitMQ 3-node → 5-node + federation | +$600/month |
| **Monitoring** | DataDog scaling | +$300/month |
| **Total Infrastructure @ 2x** | | **$25,166/month** (+56%) |

### Team Additions @ 2x
- +1 Backend Engineer (matching service scaling)
- +0.5 Payments Specialist (PCI compliance, chargeback management)
- +1 SRE (multi-region readiness)
- **Cost:** ~$280K/year all-in

---

## 10x Growth Scenario (24 months forward)
**Assumption:** 120K providers, 450K customers, 21K transactions/day, 180K requests/day, peak 800 req/min

### What Breaks First
1. **Provider Network Complexity:** 120K providers with relationships (ratings, reviews, availability) become unmanageable in single database
2. **Matching Algorithm Scalability:** ML-based matching (not just keyword search) becomes computationally expensive
3. **Geospatial Queries:** Regional distribution of providers requires distributed search (can't serve all regions from single index)
4. **Fraud Detection:** 21K/day transactions = higher fraud risk; need real-time anomaly detection
5. **Payment Processor Cost:** 21K transactions/day × $0.30 fee = $6.3K/day (prohibitive); need alternative payment models

### Required Infrastructure Changes
| Component | Current → 10x | Incremental Cost |
|-----------|--------------|-----------------|
| **Matching Service** | 3 × t3.xlarge → 20 × t3.2xlarge + Kubernetes (auto-scale) | +$3,456/month |
| **ML-Based Matching** | 0 → GPU cluster for ranking/recommendation | +$5,600/month |
| **Provider Database** | r5.xlarge → r6i.4xlarge + 10 read replicas + sharding (2 shards) | +$10,000/month |
| **Geospatial Search** | Single Elasticsearch → Multi-region Elasticsearch (US/EU/APAC) | +$3,000/month |
| **Real-Time Status** | Polling → Event-driven provider status (Kafka streams) | +$1,500/month |
| **Fraud Detection** | 0 → Real-time anomaly detection (ML model) | +$2,000/month |
| **Payment Processing** | Direct processor → Payment processor + blockchain escrow (lower fees) | +$5,000/month (negotiated rates) |
| **Data Warehouse** | BigQuery for analytics + reputation building | +$2,000/month |
| **Message Queue** | RabbitMQ → Apache Kafka (higher throughput) | +$1,500/month |
| **Monitoring Enterprise** | DataDog → Datadog Enterprise | +$1,500/month |
| **Total Infrastructure @ 10x** | | **$59,716/month** (+269%) |

### Architecture Changes @ 10x

**Geospatial Distribution:**
- Current: Single Elasticsearch index (all providers, queried from single data center)
- At 10x: Multi-region deployment (US, EU, APAC) with local provider indexes
- Enables compliance (data residency), faster queries (local searches), failover (region-level resilience)

**Real-Time Provider Status (vs. 4-hour polling):**
- Current: Poll every 4 hours; stale data possible
- At 10x: Event-driven; provider updates status → streamed to system (minutes to seconds latency)
- Improves availability accuracy to 99%+

**ML-Based Matching (vs. keyword search):**
- Current: Keyword + location search
- At 10x: ML ranking model learns provider quality, customer preferences, historical success
- Improves match quality; increases customer conversion/satisfaction

**Payment Processing Innovation:**
- Current: Traditional payment processor (~$0.30 per transaction)
- At 10x: Hybrid model (processor for low-value, blockchain escrow for high-value, subscription escrow for recurring)
- Reduces per-transaction cost by 40%; enables micro-transactions

### Team Scaling @ 10x
| Role | Current → 10x | Notes |
|---|---|---|
| **Backend Engineers** | 3 → 12 (3 matching, 3 payments, 2 platform, 2 fraud, 2 data) | Domain-driven teams |
| **Payments Specialist** | 1 → 3 (processor integration, chargeback, fraud) | Compliance + revenue ops |
| **Data Scientists** | 1 → 4 (matching ML, fraud detection, recommendation, churn) | Predictive models |
| **SRE/DevOps** | 1 → 4 (multi-region, incident response, cost optimization) | Distributed systems |
| **Product Manager** | 1 → 2 (core PM + growth/monetization specialist) | Business model evolution |
| **Trust & Safety** | 0 → 3 (provider verification, fraud investigation, appeals) | Compliance + customer trust |
| **Total Cost** | ~$550K/year → ~$2.2M/year | +300% headcount for 10x growth |

---

## Cost Optimization Timeline

### Phase 1: Current → 2x (Months 0-6)
1. **Provider Status Caching:** Cache availability status (reduce polling by 50%)
2. **Search Optimization:** Add provider popularity index (reduce ES query complexity by 40%)
3. **Payment Batching:** Batch small transactions (reduce processor calls by 20%)

### Phase 2: 2x → 5x (Months 6-12)
1. **Event-Driven Status:** Replace polling with provider-pushed status updates (eliminate polling overhead)
2. **Regional Sharding:** Split providers by region (enable parallel queries, reduce per-shard load)
3. **Blockchain Escrow:** For high-value transactions, use blockchain (cheaper than traditional processor)

### Phase 3: 5x → 10x (Months 12-24)
1. **ML Matching:** Use ML to rank providers (improve match quality, reduce latency via model inference vs. DB lookup)
2. **Provider Subscriptions:** Recurring providers move to subscription escrow (predictable, lower per-transaction cost)
3. **Marketplace Economics:** Dynamic pricing/fees based on demand (optimize revenue per request)

---

## Monitoring & Decision Gates

### Weekly Metrics
- Matching latency p95: Alert if >3s
- Request throughput: Alert if <95% of requests processed
- Provider availability accuracy: Alert if <94%
- Payment success rate: Alert if <99.5%

### Monthly Decision Gates
| Metric | Threshold | Action |
|--------|-----------|--------|
| Matching latency | p95 >5s × 2 days | Scale matching service or optimize search |
| Throughput | <98% processed × 1 day | Scale matching; reduce feature load |
| Availability accuracy | <93% × 1 week | Increase polling frequency or switch to events |
| Payment failures | >0.5% × 1 day | Investigate processor; scale escrow |
| Provider response rate | <85% average | Improve matching (suggest relevant providers) |
| GMV | Trending down | Investigate user experience; A/B test matching |

