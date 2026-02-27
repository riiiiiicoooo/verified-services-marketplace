# Data Model: Verified Services Marketplace

**Last Updated:** January 2025

---

## 1. Entity Relationship Diagram

```
┌──────────────┐       ┌──────────────────┐       ┌──────────────┐
│  customers   │       │ service_requests  │       │  providers   │
│              │       │                   │       │              │
│  id (PK)     │──1:N──│  id (PK)          │       │  id (PK)     │
│  user_id(FK) │       │  customer_id (FK) │       │  user_id(FK) │
│  name        │       │  category_id (FK) │       │  business_name│
│  email       │       │  title            │       │  tier        │
│  phone       │       │  description      │       │  composite_  │
│  location    │       │  location (POINT) │       │  rating      │
│              │       │  status           │       │  service_    │
│              │       │  budget_min/max   │       │  location    │
│              │       │  preferred_dates  │       │  (POINT)     │
│              │       │  bid_window_end   │       │  radius_miles│
│              │       │                   │       │  is_active   │
└──────────────┘       └────────┬──────────┘       └──────┬───────┘
                                │                          │
                    ┌───────────┼──────────────┐           │
                    │           │              │           │
                    ▼           ▼              ▼           │
            ┌────────────┐ ┌────────┐ ┌──────────────┐    │
            │  matched_  │ │  bids  │ │  job_photos  │    │
            │  providers │ │        │ │              │    │
            │            │ │ id(PK) │ │  id (PK)     │    │
            │ request_id │ │ request│ │  request_id  │    │
            │ provider_id│ │ _id    │ │  uploaded_by  │    │
            │ notified_at│ │ provid │ │  url         │    │
            │ score      │ │ er_id  │ │  phase       │    │
            └────────────┘ │ amount │ └──────────────┘    │
                           │ timeline│                     │
                           │ scope   │                     │
                           │ status  │                     │
                           └───┬────┘                     │
                               │                          │
                               ▼                          │
                       ┌──────────────┐                   │
                       │  payments    │                   │
                       │              │                   │
                       │  id (PK)     │                   │
                       │  bid_id (FK) │                   │
                       │  stripe_pi_id│                   │
                       │  amount      │                   │
                       │  platform_fee│                   │
                       │  provider_   │                   │
                       │  payout      │                   │
                       │  status      │                   │
                       │  escrow_     │                   │
                       │  captured_at │                   │
                       └──────────────┘                   │
                                                          │
    ┌──────────────────┬──────────────────┬───────────────┤
    │                  │                  │               │
    ▼                  ▼                  ▼               │
┌──────────┐  ┌──────────────┐  ┌──────────────────┐     │
│ provider_│  │ provider_    │  │ verifications    │     │
│ services │  │ availability │  │                  │     │
│          │  │              │  │ id (PK)          │     │
│ id (PK)  │  │ id (PK)      │  │ provider_id (FK) │     │
│ provider │  │ provider_id  │  │ check_type       │     │
│ _id (FK) │  │ day_of_week  │  │ status           │     │
│ category │  │ start_time   │  │ vendor_ref_id    │     │
│ _id (FK) │  │ end_time     │  │ expires_at       │     │
│          │  │ is_available │  │ document_url     │     │
└──────────┘  └──────────────┘  │ reviewed_by      │     │
                                │ reviewed_at      │     │
                                └──────────────────┘     │
                                                          │
                              ┌────────────────────┐      │
                              │  reviews           │      │
                              │                    │      │
                              │  id (PK)           │      │
                              │  request_id (FK)   │◄─────┘
                              │  customer_id (FK)  │
                              │  provider_id (FK)  │
                              │  quality_score     │
                              │  timeliness_score  │
                              │  communication_    │
                              │  score             │
                              │  composite_score   │
                              │  comment           │
                              │  provider_response │
                              │  is_visible        │
                              └────────────────────┘

┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│ service_         │   │  disputes        │   │  audit_log       │
│ categories       │   │                  │   │                  │
│                  │   │  id (PK)         │   │  id (PK)         │
│  id (PK)         │   │  request_id (FK) │   │  actor_id        │
│  name            │   │  filed_by (FK)   │   │  actor_role      │
│  parent_id (FK)  │   │  reason          │   │  action          │
│  is_active       │   │  description     │   │  entity_type     │
│  sort_order      │   │  evidence_urls   │   │  entity_id       │
│                  │   │  status          │   │  changes (JSONB) │
│                  │   │  resolution      │   │  ip_address      │
│                  │   │  resolved_by(FK) │   │  created_at      │
│                  │   │  refund_amount   │   │                  │
└──────────────────┘   └──────────────────┘   └──────────────────┘
```

---

## 2. Schema Definitions

### 2.1 Users and Auth

```sql
-- Supabase Auth handles the auth.users table
-- These are the application-level profile tables

CREATE TABLE customers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    email           TEXT NOT NULL,
    phone           TEXT,
    location        GEOGRAPHY(POINT, 4326),  -- PostGIS
    address_line1   TEXT,
    address_city    TEXT,
    address_state   TEXT,
    address_zip     TEXT,
    notification_preferences JSONB DEFAULT '{"email": true, "sms": true, "push": true}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unique_customer_user UNIQUE (user_id)
);

CREATE TABLE providers (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    business_name       TEXT NOT NULL,
    contact_name        TEXT NOT NULL,
    email               TEXT NOT NULL,
    phone               TEXT NOT NULL,
    bio                 TEXT,
    profile_photo_url   TEXT,
    service_location    GEOGRAPHY(POINT, 4326),  -- PostGIS: provider base location
    radius_miles        INTEGER NOT NULL DEFAULT 25,
    address_line1       TEXT,
    address_city        TEXT,
    address_state       TEXT,
    address_zip         TEXT,
    tier                TEXT NOT NULL DEFAULT 'standard'
                        CHECK (tier IN ('standard', 'preferred', 'elite')),
    composite_rating    NUMERIC(3,2),  -- NULL until 5+ reviews
    total_completed_jobs INTEGER NOT NULL DEFAULT 0,
    total_reviews       INTEGER NOT NULL DEFAULT 0,
    completion_rate     NUMERIC(5,4) DEFAULT 0,  -- 0.0000 to 1.0000
    avg_response_minutes INTEGER,
    complaint_rate      NUMERIC(5,4) DEFAULT 0,
    max_concurrent_jobs INTEGER NOT NULL DEFAULT 5,
    verification_status TEXT NOT NULL DEFAULT 'pending'
                        CHECK (verification_status IN (
                            'pending', 'documents_submitted', 'checks_in_progress',
                            'operator_review', 'verified', 'rejected', 'suspended'
                        )),
    is_active           BOOLEAN NOT NULL DEFAULT false,
    platform_fee_rate   NUMERIC(4,3) NOT NULL DEFAULT 0.150,  -- 15% default, 12% for Elite
    stripe_account_id   TEXT,  -- Stripe Connect account
    notification_preferences JSONB DEFAULT '{"email": true, "sms": true, "push": true}',
    suspended_at        TIMESTAMPTZ,
    suspended_reason    TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unique_provider_user UNIQUE (user_id)
);
```

### 2.2 Service Categories

```sql
CREATE TABLE service_categories (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    slug        TEXT NOT NULL UNIQUE,
    parent_id   UUID REFERENCES service_categories(id),  -- NULL = top-level
    description TEXT,
    icon_name   TEXT,  -- lucide icon identifier
    is_active   BOOLEAN NOT NULL DEFAULT true,
    sort_order  INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Example: "Plumbing" (parent) -> "Repair", "Installation", "Emergency" (children)

CREATE TABLE provider_services (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id     UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    category_id     UUID NOT NULL REFERENCES service_categories(id),
    years_experience INTEGER,
    description     TEXT,  -- Provider's description of their expertise in this category
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unique_provider_category UNIQUE (provider_id, category_id)
);
```

### 2.3 Service Requests

```sql
CREATE TABLE service_requests (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id         UUID NOT NULL REFERENCES customers(id),
    category_id         UUID NOT NULL REFERENCES service_categories(id),
    title               TEXT NOT NULL,
    description         TEXT NOT NULL,
    location            GEOGRAPHY(POINT, 4326) NOT NULL,
    address_line1       TEXT,
    address_city        TEXT,
    address_state       TEXT,
    address_zip         TEXT,
    preferred_date_start DATE,
    preferred_date_end  DATE,
    preferred_time_slot TEXT CHECK (preferred_time_slot IN (
                            'morning', 'afternoon', 'evening', 'flexible'
                        )),
    budget_min          NUMERIC(10,2),
    budget_max          NUMERIC(10,2),
    status              TEXT NOT NULL DEFAULT 'open'
                        CHECK (status IN (
                            'draft', 'open', 'matching', 'bidding', 'awarded',
                            'scheduled', 'in_progress', 'completed', 'disputed',
                            'resolved', 'cancelled', 'closed'
                        )),
    bid_window_end      TIMESTAMPTZ,  -- When bidding closes (default: 24h after matching)
    awarded_bid_id      UUID,  -- Set when customer selects a bid
    awarded_provider_id UUID REFERENCES providers(id),
    scheduled_date      DATE,
    scheduled_time      TEXT,
    completed_at        TIMESTAMPTZ,
    cancelled_at        TIMESTAMPTZ,
    cancelled_by        UUID,
    cancellation_reason TEXT,
    matching_radius_miles INTEGER NOT NULL DEFAULT 25,
    total_bids          INTEGER NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### 2.4 Matching and Bids

```sql
CREATE TABLE matched_providers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id      UUID NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
    provider_id     UUID NOT NULL REFERENCES providers(id),
    composite_score NUMERIC(6,4) NOT NULL,  -- Matching algorithm output
    distance_miles  NUMERIC(6,2) NOT NULL,
    notified_at     TIMESTAMPTZ,
    notification_channels JSONB,  -- {"push": true, "email": true, "sms": false}
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unique_match UNIQUE (request_id, provider_id)
);

CREATE TABLE bids (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id      UUID NOT NULL REFERENCES service_requests(id),
    provider_id     UUID NOT NULL REFERENCES providers(id),
    amount          NUMERIC(10,2) NOT NULL,
    estimated_days  INTEGER,  -- Estimated calendar days to complete
    scope_of_work   TEXT NOT NULL,
    notes           TEXT,
    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN (
                        'pending', 'accepted', 'rejected', 'withdrawn', 'expired'
                    )),
    accepted_at     TIMESTAMPTZ,
    rejected_at     TIMESTAMPTZ,
    withdrawn_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unique_bid UNIQUE (request_id, provider_id)
);
```

### 2.5 Payments

```sql
CREATE TABLE payments (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id          UUID NOT NULL REFERENCES service_requests(id),
    bid_id              UUID NOT NULL REFERENCES bids(id),
    customer_id         UUID NOT NULL REFERENCES customers(id),
    provider_id         UUID NOT NULL REFERENCES providers(id),
    stripe_payment_intent_id TEXT NOT NULL,
    stripe_transfer_id  TEXT,  -- Set when transfer to provider is created
    amount_total        NUMERIC(10,2) NOT NULL,  -- Bid amount + customer fee
    bid_amount          NUMERIC(10,2) NOT NULL,  -- Original bid amount
    customer_fee        NUMERIC(10,2) NOT NULL,  -- 5% customer service fee
    platform_fee        NUMERIC(10,2) NOT NULL,  -- 15% (or 12% Elite) provider fee
    provider_payout     NUMERIC(10,2) NOT NULL,  -- bid_amount - platform_fee
    stripe_processing_fee NUMERIC(10,2),  -- 2.9% + $0.30 (platform absorbs)
    status              TEXT NOT NULL DEFAULT 'pending'
                        CHECK (status IN (
                            'pending', 'escrow_held', 'captured', 'partially_refunded',
                            'refunded', 'failed', 'cancelled'
                        )),
    escrow_held_at      TIMESTAMPTZ,
    captured_at         TIMESTAMPTZ,
    refunded_at         TIMESTAMPTZ,
    refund_amount       NUMERIC(10,2),
    refund_reason       TEXT,
    payout_status       TEXT DEFAULT 'pending'
                        CHECK (payout_status IN ('pending', 'scheduled', 'paid', 'failed')),
    payout_scheduled_at TIMESTAMPTZ,
    payout_completed_at TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE payment_milestones (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id      UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
    milestone_name  TEXT NOT NULL,
    amount          NUMERIC(10,2) NOT NULL,
    percentage      NUMERIC(5,2) NOT NULL,  -- Percentage of total
    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'released', 'disputed')),
    released_at     TIMESTAMPTZ,
    sort_order      INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### 2.6 Reviews

```sql
CREATE TABLE reviews (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id          UUID NOT NULL REFERENCES service_requests(id),
    customer_id         UUID NOT NULL REFERENCES customers(id),
    provider_id         UUID NOT NULL REFERENCES providers(id),
    quality_score       INTEGER NOT NULL CHECK (quality_score BETWEEN 1 AND 5),
    timeliness_score    INTEGER NOT NULL CHECK (timeliness_score BETWEEN 1 AND 5),
    communication_score INTEGER NOT NULL CHECK (communication_score BETWEEN 1 AND 5),
    composite_score     NUMERIC(3,2) NOT NULL,  -- Weighted: 0.5*Q + 0.3*T + 0.2*C
    comment             TEXT,
    would_book_again    BOOLEAN,
    provider_response   TEXT,
    provider_responded_at TIMESTAMPTZ,
    is_visible          BOOLEAN NOT NULL DEFAULT false,  -- Visible after both submit or 7-day window
    is_flagged          BOOLEAN NOT NULL DEFAULT false,
    flagged_reason      TEXT,
    moderated_by        UUID,
    moderated_at        TIMESTAMPTZ,
    edit_window_end     TIMESTAMPTZ,  -- 48 hours after creation
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unique_review UNIQUE (request_id, customer_id)
);
```

### 2.7 Verifications

```sql
CREATE TABLE verifications (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id     UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    check_type      TEXT NOT NULL
                    CHECK (check_type IN (
                        'identity', 'criminal_background', 'trade_license',
                        'business_license', 'general_liability_insurance',
                        'workers_comp_insurance'
                    )),
    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN (
                        'pending', 'in_progress', 'passed', 'failed',
                        'expired', 'requires_manual_review'
                    )),
    vendor          TEXT,  -- 'checkr', 'state_api', 'manual'
    vendor_ref_id   TEXT,  -- External reference (Checkr report ID, etc.)
    document_url    TEXT,  -- Supabase Storage path to uploaded document
    document_number TEXT,  -- License number, policy number, etc.
    issued_at       DATE,
    expires_at      DATE,
    verified_at     TIMESTAMPTZ,
    reviewed_by     UUID,  -- Operator who did manual review
    reviewed_at     TIMESTAMPTZ,
    review_notes    TEXT,
    failure_reason  TEXT,
    reminder_30d_sent BOOLEAN DEFAULT false,
    reminder_14d_sent BOOLEAN DEFAULT false,
    reminder_7d_sent  BOOLEAN DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### 2.8 Disputes

```sql
CREATE TABLE disputes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id      UUID NOT NULL REFERENCES service_requests(id),
    payment_id      UUID REFERENCES payments(id),
    filed_by        UUID NOT NULL,  -- customer or provider user_id
    filed_by_role   TEXT NOT NULL CHECK (filed_by_role IN ('customer', 'provider')),
    reason          TEXT NOT NULL
                    CHECK (reason IN (
                        'incomplete_work', 'poor_quality', 'no_show',
                        'overcharged', 'property_damage', 'provider_dispute',
                        'other'
                    )),
    description     TEXT NOT NULL,
    evidence_urls   TEXT[],  -- Array of photo/document URLs
    status          TEXT NOT NULL DEFAULT 'open'
                    CHECK (status IN (
                        'open', 'under_review', 'awaiting_response',
                        'resolved', 'escalated'
                    )),
    resolution      TEXT CHECK (resolution IN (
                        'full_refund', 'partial_refund', 'dismissed',
                        'provider_suspended', 'mutual_agreement'
                    )),
    resolution_notes TEXT,
    refund_amount   NUMERIC(10,2),
    resolved_by     UUID,  -- Operator user_id
    resolved_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### 2.9 Messaging

```sql
CREATE TABLE messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id      UUID NOT NULL REFERENCES service_requests(id),
    sender_id       UUID NOT NULL,
    sender_role     TEXT NOT NULL CHECK (sender_role IN ('customer', 'provider', 'operator')),
    content         TEXT NOT NULL,
    is_system       BOOLEAN NOT NULL DEFAULT false,  -- System-generated messages (status changes)
    read_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### 2.10 Job Photos

```sql
CREATE TABLE job_photos (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id      UUID NOT NULL REFERENCES service_requests(id),
    uploaded_by     UUID NOT NULL,
    uploaded_by_role TEXT NOT NULL CHECK (uploaded_by_role IN ('customer', 'provider')),
    photo_url       TEXT NOT NULL,
    phase           TEXT NOT NULL CHECK (phase IN ('before', 'during', 'after')),
    caption         TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### 2.11 Audit Log

```sql
CREATE TABLE audit_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id        UUID NOT NULL,
    actor_role      TEXT NOT NULL CHECK (actor_role IN ('customer', 'provider', 'operator', 'system')),
    action          TEXT NOT NULL,  -- 'provider.approved', 'dispute.resolved', 'payment.refunded', etc.
    entity_type     TEXT NOT NULL,  -- 'provider', 'request', 'payment', 'dispute', etc.
    entity_id       UUID NOT NULL,
    changes         JSONB,  -- {"field": {"old": "value", "new": "value"}}
    ip_address      INET,
    user_agent      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Audit log is append-only (no UPDATE or DELETE policies)
```

### 2.12 Notifications

```sql
CREATE TABLE notifications (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL,
    user_role       TEXT NOT NULL CHECK (user_role IN ('customer', 'provider', 'operator')),
    type            TEXT NOT NULL,  -- 'new_bid', 'job_awarded', 'payment_released', etc.
    title           TEXT NOT NULL,
    body            TEXT NOT NULL,
    data            JSONB,  -- Deep link data: {"request_id": "...", "screen": "bid_detail"}
    channels_sent   JSONB,  -- {"push": true, "email": true, "sms": false}
    read_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## 3. Indexing Strategy

### 3.1 Geospatial Indexes (PostGIS GIST)

```sql
-- Provider location for radius matching
CREATE INDEX idx_providers_service_location
    ON providers USING GIST (service_location);

-- Service request location for reverse lookups
CREATE INDEX idx_requests_location
    ON service_requests USING GIST (location);

-- Customer location
CREATE INDEX idx_customers_location
    ON customers USING GIST (location);
```

### 3.2 B-tree Indexes (Filtering and Sorting)

```sql
-- Matching engine: find active verified providers by service type
CREATE INDEX idx_provider_services_category
    ON provider_services (category_id, provider_id);

CREATE INDEX idx_providers_active_verified
    ON providers (verification_status, is_active)
    WHERE verification_status = 'verified' AND is_active = true;

-- Request queries: by customer, by status, by category
CREATE INDEX idx_requests_customer ON service_requests (customer_id, created_at DESC);
CREATE INDEX idx_requests_status ON service_requests (status) WHERE status NOT IN ('closed', 'cancelled');
CREATE INDEX idx_requests_category ON service_requests (category_id, status);

-- Bid queries: by request, by provider
CREATE INDEX idx_bids_request ON bids (request_id, created_at DESC);
CREATE INDEX idx_bids_provider ON bids (provider_id, status);

-- Payment queries: by status, by provider
CREATE INDEX idx_payments_status ON payments (status) WHERE status IN ('escrow_held', 'pending');
CREATE INDEX idx_payments_provider ON payments (provider_id, payout_status);

-- Verification: expiring credentials
CREATE INDEX idx_verifications_expiry
    ON verifications (expires_at, status)
    WHERE status = 'passed' AND expires_at IS NOT NULL;

-- Review queries: by provider, for rating calculation
CREATE INDEX idx_reviews_provider ON reviews (provider_id, created_at DESC);

-- Audit log: by entity, by actor, by time
CREATE INDEX idx_audit_entity ON audit_log (entity_type, entity_id, created_at DESC);
CREATE INDEX idx_audit_actor ON audit_log (actor_id, created_at DESC);

-- Notifications: unread by user
CREATE INDEX idx_notifications_unread
    ON notifications (user_id, created_at DESC)
    WHERE read_at IS NULL;
```

### 3.3 Materialized Views

```sql
-- Provider availability (refreshed hourly)
-- Pre-computes which providers have capacity, avoiding complex joins during matching
CREATE MATERIALIZED VIEW provider_availability AS
SELECT
    p.id AS provider_id,
    p.business_name,
    p.service_location,
    p.radius_miles,
    p.tier,
    p.composite_rating,
    p.completion_rate,
    p.avg_response_minutes,
    p.max_concurrent_jobs,
    COUNT(sr.id) FILTER (WHERE sr.status IN ('awarded', 'scheduled', 'in_progress')) AS active_jobs,
    p.max_concurrent_jobs - COUNT(sr.id) FILTER (
        WHERE sr.status IN ('awarded', 'scheduled', 'in_progress')
    ) AS available_capacity
FROM providers p
LEFT JOIN service_requests sr ON sr.awarded_provider_id = p.id
WHERE p.verification_status = 'verified'
    AND p.is_active = true
GROUP BY p.id;

CREATE UNIQUE INDEX idx_mv_provider_availability ON provider_availability (provider_id);
CREATE INDEX idx_mv_provider_availability_location ON provider_availability USING GIST (service_location);

-- Marketplace health metrics (refreshed every 5 minutes)
CREATE MATERIALIZED VIEW marketplace_health AS
SELECT
    DATE_TRUNC('day', sr.created_at) AS day,
    sr.address_state AS market,
    COUNT(sr.id) AS total_requests,
    COUNT(sr.id) FILTER (WHERE sr.total_bids >= 3) AS requests_with_3plus_bids,
    ROUND(
        COUNT(sr.id) FILTER (WHERE sr.total_bids >= 3)::NUMERIC / NULLIF(COUNT(sr.id), 0),
        4
    ) AS bid_coverage_rate,
    AVG(b.amount) AS avg_bid_amount,
    COUNT(DISTINCT sr.awarded_provider_id) AS unique_providers_awarded,
    SUM(pay.bid_amount) FILTER (WHERE pay.status = 'captured') AS daily_gmv,
    AVG(EXTRACT(EPOCH FROM (b.created_at - sr.created_at)) / 3600)
        AS avg_hours_to_first_bid
FROM service_requests sr
LEFT JOIN bids b ON b.request_id = sr.id
LEFT JOIN payments pay ON pay.request_id = sr.id
WHERE sr.created_at > NOW() - INTERVAL '90 days'
GROUP BY DATE_TRUNC('day', sr.created_at), sr.address_state;
```

---

## 4. Row-Level Security Policies

```sql
-- Customers see only their own data
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
CREATE POLICY customer_own_data ON customers
    FOR ALL USING (user_id = auth.uid());

-- Providers see only their own profile
ALTER TABLE providers ENABLE ROW LEVEL SECURITY;
CREATE POLICY provider_own_data ON providers
    FOR ALL USING (user_id = auth.uid());

-- Customers see public provider profiles (read-only)
CREATE POLICY customer_view_providers ON providers
    FOR SELECT USING (
        auth.jwt() ->> 'role' = 'customer'
        AND verification_status = 'verified'
        AND is_active = true
    );

-- Customers see only their requests; providers see requests they're matched to
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY customer_own_requests ON service_requests
    FOR ALL USING (customer_id IN (SELECT id FROM customers WHERE user_id = auth.uid()));

CREATE POLICY provider_matched_requests ON service_requests
    FOR SELECT USING (
        id IN (
            SELECT request_id FROM matched_providers mp
            JOIN providers p ON p.id = mp.provider_id
            WHERE p.user_id = auth.uid()
        )
    );

-- Bids: providers see own bids; customers see bids on their requests
ALTER TABLE bids ENABLE ROW LEVEL SECURITY;

CREATE POLICY provider_own_bids ON bids
    FOR ALL USING (
        provider_id IN (SELECT id FROM providers WHERE user_id = auth.uid())
    );

CREATE POLICY customer_view_bids ON bids
    FOR SELECT USING (
        request_id IN (
            SELECT id FROM service_requests sr
            JOIN customers c ON c.id = sr.customer_id
            WHERE c.user_id = auth.uid()
        )
    );

-- Reviews: visible only when is_visible = true (double-blind protection)
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY public_visible_reviews ON reviews
    FOR SELECT USING (is_visible = true);

CREATE POLICY customer_own_reviews ON reviews
    FOR ALL USING (
        customer_id IN (SELECT id FROM customers WHERE user_id = auth.uid())
    );

-- Payments: customers and providers see only their own
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY customer_own_payments ON payments
    FOR SELECT USING (
        customer_id IN (SELECT id FROM customers WHERE user_id = auth.uid())
    );

CREATE POLICY provider_own_payments ON payments
    FOR SELECT USING (
        provider_id IN (SELECT id FROM providers WHERE user_id = auth.uid())
    );

-- Operator can see everything
CREATE POLICY operator_full_access_customers ON customers
    FOR ALL USING (auth.jwt() ->> 'role' = 'operator');
CREATE POLICY operator_full_access_providers ON providers
    FOR ALL USING (auth.jwt() ->> 'role' = 'operator');
CREATE POLICY operator_full_access_requests ON service_requests
    FOR ALL USING (auth.jwt() ->> 'role' = 'operator');
CREATE POLICY operator_full_access_bids ON bids
    FOR ALL USING (auth.jwt() ->> 'role' = 'operator');
CREATE POLICY operator_full_access_payments ON payments
    FOR ALL USING (auth.jwt() ->> 'role' = 'operator');
CREATE POLICY operator_full_access_reviews ON reviews
    FOR ALL USING (auth.jwt() ->> 'role' = 'operator');
CREATE POLICY operator_full_access_disputes ON disputes
    FOR ALL USING (auth.jwt() ->> 'role' = 'operator');
```

---

## 5. Key Query Patterns

### 5.1 Matching Engine Query

```sql
-- Find and rank verified providers within radius who offer the requested service
SELECT
    p.id,
    p.business_name,
    p.tier,
    p.composite_rating,
    p.completion_rate,
    p.avg_response_minutes,
    pa.available_capacity,
    ST_Distance(p.service_location, $1::geography) / 1609.34 AS distance_miles,
    (
        0.35 * COALESCE(p.composite_rating / 5.0, 0.5) +
        0.25 * COALESCE(p.completion_rate, 0.5) +
        0.20 * CASE
            WHEN p.avg_response_minutes IS NULL THEN 0.5
            WHEN p.avg_response_minutes <= 60 THEN 1.0
            WHEN p.avg_response_minutes <= 240 THEN 0.7
            ELSE 0.4
        END +
        0.15 * CASE p.tier
            WHEN 'elite' THEN 1.0
            WHEN 'preferred' THEN 0.7
            ELSE 0.4
        END +
        0.05 * CASE
            WHEN p.updated_at > NOW() - INTERVAL '7 days' THEN 1.0
            WHEN p.updated_at > NOW() - INTERVAL '30 days' THEN 0.6
            ELSE 0.3
        END
    ) AS composite_score
FROM providers p
JOIN provider_services ps ON ps.provider_id = p.id
JOIN provider_availability pa ON pa.provider_id = p.id
WHERE ps.category_id = $2                                    -- Service type match
    AND ST_DWithin(p.service_location, $1::geography, $3)    -- Within radius (meters)
    AND p.verification_status = 'verified'
    AND p.is_active = true
    AND pa.available_capacity > 0                             -- Has capacity
ORDER BY composite_score DESC
LIMIT 10;
```

### 5.2 Provider Earnings Dashboard

```sql
-- Provider earnings summary
SELECT
    SUM(provider_payout) FILTER (WHERE payout_status = 'paid') AS total_earned,
    SUM(provider_payout) FILTER (WHERE status = 'captured' AND payout_status = 'pending') AS pending_payout,
    SUM(provider_payout) FILTER (WHERE status = 'escrow_held') AS in_escrow,
    COUNT(*) FILTER (WHERE status = 'captured' AND payout_status = 'paid') AS completed_payments,
    AVG(provider_payout) FILTER (WHERE payout_status = 'paid') AS avg_job_payout
FROM payments
WHERE provider_id = $1;
```

### 5.3 Marketplace Health Dashboard

```sql
-- Daily marketplace metrics (uses materialized view)
SELECT
    day,
    market,
    total_requests,
    bid_coverage_rate,
    daily_gmv,
    avg_hours_to_first_bid,
    requests_with_3plus_bids
FROM marketplace_health
WHERE day >= $1 AND day <= $2
ORDER BY day DESC, market;
```

---

## 6. Data Lifecycle

### 6.1 Request State Machine

```
draft ──────► open ──────► matching ──────► bidding ──────► awarded
                                                              │
                                                              ▼
                          cancelled ◄── ── ── ── ──     scheduled
                          (any state                       │
                           before                          ▼
                           in_progress)               in_progress
                                                          │
                                                    ┌─────┴─────┐
                                                    │           │
                                                    ▼           ▼
                                               completed    disputed
                                                    │           │
                                                    ▼           ▼
                                                  closed     resolved
                                                                │
                                                                ▼
                                                              closed
```

### 6.2 Provider Verification States

```
pending ──► documents_submitted ──► checks_in_progress ──► operator_review ──► verified
                                          │                                       │
                                          ▼                                       ▼
                                       rejected ◄── ── ── ── ── ── ──       suspended
                                          │                                  (credential
                                          ▼                                   expiry or
                                    resubmit flow                            misconduct)
                                    (back to                                      │
                                     documents_                                   ▼
                                     submitted)                              reactivation
                                                                             flow (back
                                                                             to verified)
```

### 6.3 Retention Policy

| Data Type | Retention | Reason |
|---|---|---|
| Active request data | Indefinite | Business records |
| Completed request data | 7 years | Tax and legal compliance |
| Audit log | 7 years (append-only) | Compliance and dispute defense |
| Provider verification documents | Duration of active relationship + 3 years | Regulatory requirements |
| Background check results (pass/fail only) | Duration of active relationship | Privacy - detailed reports not stored |
| Chat messages | 3 years after job completion | Dispute evidence window |
| Job photos | 3 years after job completion | Dispute evidence window |
| Payment records | 7 years | Tax compliance (1099 generation) |
| Notification records | 90 days | Operational only |
| Session/cache data (Redis) | 24 hours | Ephemeral |
