# Production Readiness Checklist

Assessment of the Verified Services Marketplace codebase against production requirements. Items marked `[x]` are implemented in the current codebase. Items marked `[ ]` are not yet implemented and would be required before production deployment.

---

## Security

### Authentication and Authorization
- [x] Multi-role authentication (customer, provider, operator) via Clerk
- [x] Role-based permission definitions (`Permissions` object in `marketplace_auth.ts`)
- [x] Role verification middleware (`requireRole`, `hasPermission` functions)
- [x] Organization/MSO support via Clerk Organizations
- [ ] Remove `unsafeMetadata` fallback for role determination (CRITICAL -- client-writable, enables privilege escalation)
- [ ] Enforce `publicMetadata`-only role assignment (server-side Clerk Backend API)
- [ ] Implement row-level security (RLS) policies in Supabase for all tables
- [ ] Add rate limiting on authentication endpoints

### Webhook Security
- [ ] Verify Stripe webhook signatures using `stripe.Webhook.construct_event()` with `STRIPE_WEBHOOK_SECRET`
- [ ] Verify Checkr webhook signatures using HMAC-SHA256 with `X-Checkr-Signature` header
- [ ] Verify Clerk webhook signatures using Svix signature verification
- [ ] Implement webhook replay attack prevention (idempotency keys / event deduplication)

### Secrets Management
- [ ] Remove hardcoded credentials from `docker-compose.yml` (database password, pgAdmin credentials)
- [ ] Move all API keys to a secrets manager (Vault, AWS Secrets Manager, or Supabase Vault)
- [ ] Replace `SUPABASE_ANON_KEY` with `SUPABASE_SERVICE_ROLE_KEY` for server-side operations in `trigger-jobs/` and `stripe/`
- [ ] Implement secret rotation policy for Stripe, Checkr, SendGrid, and Twilio API keys
- [ ] Add `.env.example` validation to prevent deployment with placeholder keys

### TLS and Network Security
- [ ] Enforce HTTPS on all endpoints (TLS 1.2+ minimum)
- [ ] Configure CORS allowlists for API endpoints
- [ ] Implement Content Security Policy (CSP) headers
- [ ] Enable HSTS (HTTP Strict Transport Security)
- [ ] Configure network segmentation between API, database, and cache layers

### PII and Sensitive Data Handling
- [x] SSN noted as "collected securely, not stored" in Checkr integration
- [x] Verification status exposed to customers (not raw PII) via `getMarketplaceSession`
- [ ] Implement field-level encryption for PII at rest (SSN, driver's license numbers, background check results)
- [ ] Use per-provider KMS keys for PII encryption
- [ ] Implement PII access audit logging (who accessed what PII and when)
- [ ] Add data masking for PII in non-production environments
- [ ] Implement PII data retention and deletion policies (right to deletion)

### FCRA Compliance (Background Checks)
- [x] Auto-disqualification offense categories defined (`AUTO_DISQUALIFY_OFFENSES`)
- [x] Individualized assessment path for "consider" results routed to manual review
- [x] Fair-chance policy documented (consistent with EEOC guidance and Ban-the-Box)
- [ ] Implement pre-adverse action notice workflow (notify applicant before rejection)
- [ ] Implement waiting period (5 business days) between pre-adverse and final adverse action
- [ ] Implement final adverse action notice with dispute rights
- [ ] Store adverse action notice delivery timestamps for compliance audit

---

## Reliability

### High Availability and Failover
- [x] Docker Compose health checks for PostgreSQL and Redis
- [x] Service dependency ordering (`depends_on` with `condition: service_healthy`)
- [ ] Multi-region database replication (primary + read replicas)
- [ ] Redis Sentinel or Redis Cluster for cache HA
- [ ] Implement circuit breakers for external API calls (Checkr, Stripe, SendGrid, Twilio)
- [ ] Define and enforce SLA targets (API p99 latency, uptime percentage)

### Backup and Recovery
- [ ] Automated daily database backups with point-in-time recovery
- [ ] Backup retention policy (minimum 30 days)
- [ ] Documented and tested disaster recovery procedure
- [ ] Regular backup restore testing (quarterly)

### Retry Logic and Error Handling
- [x] Trigger.dev step-based retry for onboarding pipeline steps
- [x] Checkr polling with 7-day timeout and 60-second intervals
- [x] Matching engine radius expansion retry when no providers found
- [x] Non-blocking error handling for notification failures (welcome email, SMS)
- [x] Payment error classification with recovery guidance (`handle_payment_errors`)
- [ ] Implement exponential backoff with jitter for external API retries
- [ ] Add dead letter queue for permanently failed webhook events
- [ ] Implement idempotency keys for all Stripe API calls

### Data Integrity
- [x] Foreign key constraints on all relational tables
- [x] CHECK constraints for enum fields (status, tier, role values)
- [x] UNIQUE constraints on business-logic keys (provider-category, request-provider matches, bid uniqueness)
- [x] Materialized views for pre-computed availability and marketplace health
- [ ] Add database migrations versioning (beyond the single `001_initial_schema.sql`)
- [ ] Implement optimistic concurrency control for bid acceptance (prevent double-accept)

---

## Observability

### Logging
- [x] Structured logging via `logging` module in Python services
- [x] Structured logging via Trigger.dev `logger` in TypeScript jobs
- [x] Log-level configuration via `LOG_LEVEL` environment variable in Docker
- [ ] Centralized log aggregation (Datadog, CloudWatch, or ELK stack)
- [ ] Request correlation IDs across service boundaries
- [ ] PII scrubbing in log output (SSN, email in Checkr API calls)
- [ ] Structured JSON log format for all services

### Metrics
- [x] Marketplace Health Index with five weighted components (liquidity, quality, supply, demand, financial)
- [x] Gini coefficient tracking for earnings distribution fairness
- [x] Market-level health assessment (healthy/watch/intervene status)
- [x] Provider tier evaluation metrics (composite rating, completion rate, complaint rate)
- [x] Bid coverage rate and fill rate metrics in materialized view
- [ ] Application performance metrics (request latency, throughput, error rate)
- [ ] Infrastructure metrics (CPU, memory, disk, network)
- [ ] Business metrics dashboards (GMV, take rate, provider churn)
- [ ] Export metrics to a time-series store (Prometheus, Datadog, CloudWatch Metrics)

### Tracing
- [ ] Distributed tracing across API, Trigger.dev jobs, and webhook handlers (OpenTelemetry)
- [ ] Trace context propagation for the verification pipeline (Checkr webhook to provider activation)
- [ ] Trace context propagation for the matching pipeline (request creation to notification delivery)

### Alerting
- [x] Feature flag health check thresholds defined (e.g., escrow payment flow 5% error rate alert)
- [x] Market intervention triggers when bid coverage or fill rate drops below thresholds
- [ ] PagerDuty/Opsgenie integration for critical alerts
- [ ] Alert on payment processing error rate exceeding 2%
- [ ] Alert on verification pipeline timeout rate
- [ ] Alert on Gini coefficient exceeding 0.55 (critical earnings concentration)
- [ ] Runbook documentation for each alert

---

## Performance

### Caching
- [x] Redis service configured in Docker Compose for caching and rate limiting
- [x] Materialized view (`provider_availability`) for pre-computed provider capacity
- [x] Materialized view (`marketplace_health`) for pre-computed health metrics
- [ ] Implement application-level caching for provider profiles and service categories
- [ ] Cache invalidation strategy for materialized view refresh
- [ ] Scheduled `REFRESH MATERIALIZED VIEW CONCURRENTLY` jobs

### Database Performance
- [x] GIST indexes on all geography columns (providers, service_requests, customers)
- [x] Partial B-tree indexes for common query patterns (active verified providers, open requests, escrow payments, unread notifications)
- [x] Composite indexes on foreign key + sort columns (bids by request, reviews by provider, audit log by entity)
- [x] Index on verification expiry for daily credential check query
- [ ] Query performance monitoring and slow query logging
- [ ] Connection pooling configuration (PgBouncer or Supabase pooler)
- [ ] Database vacuuming and statistics maintenance schedule

### Load Testing
- [ ] Load test the PostGIS matching query at target scale (1000+ providers, 100 concurrent requests)
- [ ] Load test the escrow payment flow under concurrent bid acceptance
- [ ] Load test webhook ingestion throughput (Stripe + Checkr concurrent callbacks)
- [ ] Establish baseline performance benchmarks and regression thresholds

### API Performance
- [ ] API response time SLO (e.g., p99 < 500ms for matching, p99 < 200ms for reads)
- [ ] Pagination for all list endpoints (bids, reviews, notifications, audit log)
- [ ] Request payload size limits
- [ ] GraphQL or sparse fieldsets to reduce over-fetching

---

## Compliance

### FCRA and Background Check Laws
- [x] Criminal background policy with auto-disqualification categories
- [x] Individualized assessment routing for non-auto-disqualifying offenses
- [x] Fair-chance approach documented (EEOC-aligned, Ban-the-Box aware)
- [ ] Adverse action notice workflow (pre-adverse, waiting period, final with dispute rights)
- [ ] State-specific Ban-the-Box compliance for jurisdictions with additional requirements
- [ ] Provider right to dispute and appeal background check findings
- [ ] Annual background policy review and legal counsel sign-off

### Financial Compliance
- [x] 1099 tax reporting data generation (`generate_1099_data` and `generate_1099_summary`)
- [x] Fee economics calculation with explicit platform/customer/provider/Stripe breakdown
- [x] Payment audit trail in `payments` table (status transitions with timestamps)
- [ ] Automated 1099-K filing integration for providers exceeding $600 annual threshold
- [ ] State sales tax calculation and remittance
- [ ] PCI DSS compliance validation (Stripe handles card data, but platform must validate scope)
- [ ] Anti-money laundering (AML) monitoring for high-value transactions

### Audit Logging
- [x] Audit log table with actor, role, action, entity, changes (JSONB), IP address, and user agent
- [x] Indexes on audit log for entity-based and actor-based queries
- [ ] Immutable audit log (append-only, prevent UPDATE/DELETE on `audit_log` table)
- [ ] Audit log retention policy (minimum 7 years for financial records)
- [ ] Automated audit log analysis for suspicious patterns

### Data Retention and Privacy
- [ ] Data retention policy for each table (PII, financial records, operational data)
- [ ] GDPR/CCPA data subject access request (DSAR) workflow
- [ ] Right to deletion implementation (with retention exceptions for legal/financial records)
- [ ] Data processing agreements (DPAs) with sub-processors (Checkr, Stripe, SendGrid, Twilio)
- [ ] Privacy policy covering all data collection and processing activities

---

## Deployment

### CI/CD Pipeline
- [x] Dockerfile for containerized deployment
- [x] Docker Compose for local development orchestration
- [x] Vercel configuration (`vercel.json`) for frontend/API deployment
- [ ] Automated test suite execution in CI (unit, integration, end-to-end)
- [ ] Linting and static analysis in CI pipeline
- [ ] Security scanning (dependency audit, SAST) in CI pipeline
- [ ] Database migration automation in deployment pipeline
- [ ] Environment promotion workflow (dev -> staging -> production)

### Rollback and Safe Deployment
- [x] Feature flag infrastructure (LaunchDarkly) with kill switches for critical features
- [x] Progressive rollout support (percentage-based, segment-based, tier-based)
- [x] Feature flag prerequisite chains preventing premature feature exposure
- [ ] Blue-green or canary deployment strategy
- [ ] Automated rollback on error rate threshold breach
- [ ] Database migration rollback scripts for each migration
- [ ] Deployment runbook with step-by-step procedures

### Infrastructure as Code
- [x] Docker Compose for local infrastructure definition
- [ ] Terraform or Pulumi for cloud infrastructure provisioning
- [ ] Infrastructure drift detection
- [ ] Secrets injection via infrastructure tooling (not environment files)

### Testing
- [x] Unit tests for escrow payment calculations (`test_escrow.py`)
- [x] Test coverage for fee economics across provider tiers (standard, elite)
- [x] Test coverage for payment error handling (card declined, insufficient funds, 3DS)
- [x] Test coverage for dispute scenarios (cancellation, no-show, partial refund)
- [x] End-to-end happy path test for full payment flow (create, hold, capture, transfer)
- [ ] Integration tests for Checkr webhook processing
- [ ] Integration tests for Stripe Connect account creation and payment flow
- [ ] Integration tests for PostGIS spatial matching queries
- [ ] Contract tests for external API integrations (Checkr, Stripe, state licensing boards)
- [ ] Performance/load tests
- [ ] Test coverage reporting with minimum threshold enforcement
