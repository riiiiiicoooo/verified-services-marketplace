-- Verified Services Marketplace: Complete Database Schema
-- PostgreSQL 15+ with PostGIS 3.3+
-- Created: 2025-03-03

-- ============================================================================
-- 1. EXTENSIONS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- ============================================================================
-- 2. USERS AND PROFILES
-- ============================================================================

CREATE TABLE IF NOT EXISTS customers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL UNIQUE,
    name            TEXT NOT NULL,
    email           TEXT NOT NULL UNIQUE,
    phone           TEXT,
    location        GEOGRAPHY(POINT, 4326),
    address_line1   TEXT,
    address_city    TEXT,
    address_state   TEXT,
    address_zip     TEXT,
    notification_preferences JSONB DEFAULT '{"email": true, "sms": true, "push": true}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS providers (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL UNIQUE,
    business_name       TEXT NOT NULL,
    contact_name        TEXT NOT NULL,
    email               TEXT NOT NULL UNIQUE,
    phone               TEXT NOT NULL,
    bio                 TEXT,
    profile_photo_url   TEXT,
    service_location    GEOGRAPHY(POINT, 4326) NOT NULL,
    radius_miles        INTEGER NOT NULL DEFAULT 25,
    address_line1       TEXT,
    address_city        TEXT,
    address_state       TEXT,
    address_zip         TEXT,
    tier                TEXT NOT NULL DEFAULT 'standard'
                        CHECK (tier IN ('standard', 'preferred', 'elite')),
    composite_rating    NUMERIC(3,2),
    total_completed_jobs INTEGER NOT NULL DEFAULT 0,
    total_reviews       INTEGER NOT NULL DEFAULT 0,
    completion_rate     NUMERIC(5,4) DEFAULT 0,
    avg_response_minutes INTEGER,
    complaint_rate      NUMERIC(5,4) DEFAULT 0,
    max_concurrent_jobs INTEGER NOT NULL DEFAULT 5,
    verification_status TEXT NOT NULL DEFAULT 'pending'
                        CHECK (verification_status IN (
                            'pending', 'documents_submitted', 'checks_in_progress',
                            'operator_review', 'verified', 'rejected', 'suspended'
                        )),
    is_active           BOOLEAN NOT NULL DEFAULT false,
    platform_fee_rate   NUMERIC(4,3) NOT NULL DEFAULT 0.150,
    stripe_account_id   TEXT,
    notification_preferences JSONB DEFAULT '{"email": true, "sms": true, "push": true}',
    suspended_at        TIMESTAMPTZ,
    suspended_reason    TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 3. SERVICE CATEGORIES
-- ============================================================================

CREATE TABLE IF NOT EXISTS service_categories (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL UNIQUE,
    slug        TEXT NOT NULL UNIQUE,
    parent_id   UUID REFERENCES service_categories(id),
    description TEXT,
    icon_name   TEXT,
    is_active   BOOLEAN NOT NULL DEFAULT true,
    sort_order  INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS provider_services (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id     UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    category_id     UUID NOT NULL REFERENCES service_categories(id),
    years_experience INTEGER,
    description     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_provider_category UNIQUE (provider_id, category_id)
);

-- ============================================================================
-- 4. SERVICE REQUESTS AND MATCHING
-- ============================================================================

CREATE TABLE IF NOT EXISTS service_requests (
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
    bid_window_end      TIMESTAMPTZ,
    awarded_bid_id      UUID,
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

CREATE TABLE IF NOT EXISTS matched_providers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id      UUID NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
    provider_id     UUID NOT NULL REFERENCES providers(id),
    composite_score NUMERIC(6,4) NOT NULL,
    distance_miles  NUMERIC(6,2) NOT NULL,
    notified_at     TIMESTAMPTZ,
    notification_channels JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_match UNIQUE (request_id, provider_id)
);

CREATE TABLE IF NOT EXISTS bids (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id      UUID NOT NULL REFERENCES service_requests(id),
    provider_id     UUID NOT NULL REFERENCES providers(id),
    amount          NUMERIC(10,2) NOT NULL,
    estimated_days  INTEGER,
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

-- ============================================================================
-- 5. PAYMENTS AND ESCROW
-- ============================================================================

CREATE TABLE IF NOT EXISTS payments (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id          UUID NOT NULL REFERENCES service_requests(id),
    bid_id              UUID NOT NULL REFERENCES bids(id),
    customer_id         UUID NOT NULL REFERENCES customers(id),
    provider_id         UUID NOT NULL REFERENCES providers(id),
    stripe_payment_intent_id TEXT NOT NULL UNIQUE,
    stripe_transfer_id  TEXT,
    amount_total        NUMERIC(10,2) NOT NULL,
    bid_amount          NUMERIC(10,2) NOT NULL,
    customer_fee        NUMERIC(10,2) NOT NULL,
    platform_fee        NUMERIC(10,2) NOT NULL,
    provider_payout     NUMERIC(10,2) NOT NULL,
    stripe_processing_fee NUMERIC(10,2),
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

CREATE TABLE IF NOT EXISTS payment_milestones (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id      UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
    milestone_name  TEXT NOT NULL,
    amount          NUMERIC(10,2) NOT NULL,
    percentage      NUMERIC(5,2) NOT NULL,
    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'released', 'disputed')),
    released_at     TIMESTAMPTZ,
    sort_order      INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 6. REVIEWS AND RATINGS
-- ============================================================================

CREATE TABLE IF NOT EXISTS reviews (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id          UUID NOT NULL REFERENCES service_requests(id),
    customer_id         UUID NOT NULL REFERENCES customers(id),
    provider_id         UUID NOT NULL REFERENCES providers(id),
    quality_score       INTEGER NOT NULL CHECK (quality_score BETWEEN 1 AND 5),
    timeliness_score    INTEGER NOT NULL CHECK (timeliness_score BETWEEN 1 AND 5),
    communication_score INTEGER NOT NULL CHECK (communication_score BETWEEN 1 AND 5),
    composite_score     NUMERIC(3,2) NOT NULL,
    comment             TEXT,
    would_book_again    BOOLEAN,
    provider_response   TEXT,
    provider_responded_at TIMESTAMPTZ,
    is_visible          BOOLEAN NOT NULL DEFAULT false,
    is_flagged          BOOLEAN NOT NULL DEFAULT false,
    flagged_reason      TEXT,
    moderated_by        UUID,
    moderated_at        TIMESTAMPTZ,
    edit_window_end     TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_review UNIQUE (request_id, customer_id)
);

-- ============================================================================
-- 7. VERIFICATIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS verifications (
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
    vendor          TEXT,
    vendor_ref_id   TEXT,
    document_url    TEXT,
    document_number TEXT,
    issued_at       DATE,
    expires_at      DATE,
    verified_at     TIMESTAMPTZ,
    reviewed_by     UUID,
    reviewed_at     TIMESTAMPTZ,
    review_notes    TEXT,
    failure_reason  TEXT,
    reminder_30d_sent BOOLEAN DEFAULT false,
    reminder_14d_sent BOOLEAN DEFAULT false,
    reminder_7d_sent  BOOLEAN DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 8. DISPUTES
-- ============================================================================

CREATE TABLE IF NOT EXISTS disputes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id      UUID NOT NULL REFERENCES service_requests(id),
    payment_id      UUID REFERENCES payments(id),
    filed_by        UUID NOT NULL,
    filed_by_role   TEXT NOT NULL CHECK (filed_by_role IN ('customer', 'provider')),
    reason          TEXT NOT NULL
                    CHECK (reason IN (
                        'incomplete_work', 'poor_quality', 'no_show',
                        'overcharged', 'property_damage', 'provider_dispute',
                        'other'
                    )),
    description     TEXT NOT NULL,
    evidence_urls   TEXT[],
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
    resolved_by     UUID,
    resolved_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 9. MESSAGING
-- ============================================================================

CREATE TABLE IF NOT EXISTS messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id      UUID NOT NULL REFERENCES service_requests(id),
    sender_id       UUID NOT NULL,
    sender_role     TEXT NOT NULL CHECK (sender_role IN ('customer', 'provider', 'operator')),
    content         TEXT NOT NULL,
    is_system       BOOLEAN NOT NULL DEFAULT false,
    read_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 10. JOB PHOTOS
-- ============================================================================

CREATE TABLE IF NOT EXISTS job_photos (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id      UUID NOT NULL REFERENCES service_requests(id),
    uploaded_by     UUID NOT NULL,
    uploaded_by_role TEXT NOT NULL CHECK (uploaded_by_role IN ('customer', 'provider')),
    photo_url       TEXT NOT NULL,
    phase           TEXT NOT NULL CHECK (phase IN ('before', 'during', 'after')),
    caption         TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 11. AUDIT LOG
-- ============================================================================

CREATE TABLE IF NOT EXISTS audit_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id        UUID NOT NULL,
    actor_role      TEXT NOT NULL CHECK (actor_role IN ('customer', 'provider', 'operator', 'system')),
    action          TEXT NOT NULL,
    entity_type     TEXT NOT NULL,
    entity_id       UUID NOT NULL,
    changes         JSONB,
    ip_address      INET,
    user_agent      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 12. NOTIFICATIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS notifications (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL,
    user_role       TEXT NOT NULL CHECK (user_role IN ('customer', 'provider', 'operator')),
    type            TEXT NOT NULL,
    title           TEXT NOT NULL,
    body            TEXT NOT NULL,
    data            JSONB,
    channels_sent   JSONB,
    read_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 13. INDEXES - GEOSPATIAL
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_providers_service_location
    ON providers USING GIST (service_location);

CREATE INDEX IF NOT EXISTS idx_requests_location
    ON service_requests USING GIST (location);

CREATE INDEX IF NOT EXISTS idx_customers_location
    ON customers USING GIST (location);

-- ============================================================================
-- 14. INDEXES - B-TREE (FILTERING AND SORTING)
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_provider_services_category
    ON provider_services (category_id, provider_id);

CREATE INDEX IF NOT EXISTS idx_providers_active_verified
    ON providers (verification_status, is_active)
    WHERE verification_status = 'verified' AND is_active = true;

CREATE INDEX IF NOT EXISTS idx_requests_customer
    ON service_requests (customer_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_requests_status
    ON service_requests (status)
    WHERE status NOT IN ('closed', 'cancelled');

CREATE INDEX IF NOT EXISTS idx_requests_category
    ON service_requests (category_id, status);

CREATE INDEX IF NOT EXISTS idx_bids_request
    ON bids (request_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_bids_provider
    ON bids (provider_id, status);

CREATE INDEX IF NOT EXISTS idx_payments_status
    ON payments (status)
    WHERE status IN ('escrow_held', 'pending');

CREATE INDEX IF NOT EXISTS idx_payments_provider
    ON payments (provider_id, payout_status);

CREATE INDEX IF NOT EXISTS idx_verifications_expiry
    ON verifications (expires_at, status)
    WHERE status = 'passed' AND expires_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_reviews_provider
    ON reviews (provider_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_entity
    ON audit_log (entity_type, entity_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_actor
    ON audit_log (actor_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_unread
    ON notifications (user_id, created_at DESC)
    WHERE read_at IS NULL;

-- ============================================================================
-- 15. MATERIALIZED VIEWS
-- ============================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS provider_availability AS
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

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_provider_availability
    ON provider_availability (provider_id);

CREATE INDEX IF NOT EXISTS idx_mv_provider_availability_location
    ON provider_availability USING GIST (service_location);

CREATE MATERIALIZED VIEW IF NOT EXISTS marketplace_health AS
SELECT
    DATE_TRUNC('day', sr.created_at)::DATE AS day,
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

CREATE INDEX IF NOT EXISTS idx_mv_marketplace_health
    ON marketplace_health (day DESC, market);
