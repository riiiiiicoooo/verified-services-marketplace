-- Verified Services Marketplace: Supabase Migration
-- PostgreSQL 15+ with PostGIS 3.3+
-- Created: 2026-03-04

-- ============================================================================
-- 1. EXTENSIONS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- ============================================================================
-- 2. CUSTOM TYPES
-- ============================================================================

CREATE TYPE verification_status_enum AS ENUM (
    'pending',
    'documents_submitted',
    'checks_in_progress',
    'operator_review',
    'verified',
    'rejected',
    'suspended'
);

CREATE TYPE provider_tier_enum AS ENUM (
    'standard',
    'preferred',
    'elite'
);

CREATE TYPE request_status_enum AS ENUM (
    'draft',
    'open',
    'matching',
    'bidding',
    'awarded',
    'scheduled',
    'in_progress',
    'completed',
    'disputed',
    'resolved',
    'cancelled',
    'closed'
);

CREATE TYPE bid_status_enum AS ENUM (
    'pending',
    'accepted',
    'rejected',
    'withdrawn',
    'expired'
);

CREATE TYPE payment_status_enum AS ENUM (
    'pending',
    'escrow_held',
    'captured',
    'partially_refunded',
    'refunded',
    'failed',
    'cancelled'
);

CREATE TYPE payout_status_enum AS ENUM (
    'pending',
    'scheduled',
    'paid',
    'failed'
);

CREATE TYPE user_role_enum AS ENUM (
    'customer',
    'provider',
    'operator'
);

-- ============================================================================
-- 3. CUSTOMERS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.customers (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id                UUID NOT NULL,
    name                        TEXT NOT NULL,
    email                       TEXT NOT NULL UNIQUE,
    phone                       TEXT,
    location                    GEOGRAPHY(POINT, 4326),
    address_line1               TEXT,
    address_city                TEXT,
    address_state               TEXT,
    address_zip                 TEXT,
    notification_preferences    JSONB DEFAULT '{"email": true, "sms": true, "push": true}',
    total_requests              INTEGER DEFAULT 0,
    total_completed_jobs        INTEGER DEFAULT 0,
    avg_rating_given            NUMERIC(3,2),
    created_at                  TIMESTAMPTZ DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_customers_auth_user_id ON public.customers(auth_user_id);
CREATE INDEX idx_customers_email ON public.customers(email);
CREATE INDEX idx_customers_location ON public.customers USING GIST(location);

-- ============================================================================
-- 4. PROVIDERS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.providers (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id                UUID NOT NULL,
    business_name               TEXT NOT NULL,
    contact_name                TEXT NOT NULL,
    email                       TEXT NOT NULL UNIQUE,
    phone                       TEXT NOT NULL,
    bio                         TEXT,
    profile_photo_url           TEXT,
    service_location            GEOGRAPHY(POINT, 4326) NOT NULL,
    radius_miles                INTEGER DEFAULT 25,
    address_line1               TEXT,
    address_city                TEXT,
    address_state               TEXT,
    address_zip                 TEXT,
    tier                        provider_tier_enum DEFAULT 'standard',
    composite_rating            NUMERIC(3,2),
    total_completed_jobs        INTEGER DEFAULT 0,
    total_reviews               INTEGER DEFAULT 0,
    completion_rate             NUMERIC(5,4) DEFAULT 0,
    avg_response_minutes        INTEGER,
    complaint_rate              NUMERIC(5,4) DEFAULT 0,
    max_concurrent_jobs         INTEGER DEFAULT 5,
    verification_status         verification_status_enum DEFAULT 'pending',
    is_active                   BOOLEAN DEFAULT false,
    platform_fee_rate           NUMERIC(4,3) DEFAULT 0.150,
    stripe_account_id           TEXT,
    stripe_account_charges_enabled BOOLEAN DEFAULT false,
    stripe_account_payouts_enabled BOOLEAN DEFAULT false,
    notification_preferences    JSONB DEFAULT '{"email": true, "sms": true, "push": true}',
    suspended_at                TIMESTAMPTZ,
    suspended_reason            TEXT,
    created_at                  TIMESTAMPTZ DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_providers_auth_user_id ON public.providers(auth_user_id);
CREATE INDEX idx_providers_email ON public.providers(email);
CREATE INDEX idx_providers_service_location ON public.providers USING GIST(service_location);
CREATE INDEX idx_providers_verification_active ON public.providers(verification_status, is_active)
    WHERE verification_status = 'verified' AND is_active = true;

-- ============================================================================
-- 5. SERVICE CATEGORIES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.service_categories (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL UNIQUE,
    slug        TEXT NOT NULL UNIQUE,
    parent_id   UUID REFERENCES public.service_categories(id),
    description TEXT,
    icon_name   TEXT,
    is_active   BOOLEAN DEFAULT true,
    sort_order  INTEGER DEFAULT 0,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_service_categories_slug ON public.service_categories(slug);

-- ============================================================================
-- 6. PROVIDER SERVICES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.provider_services (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id         UUID NOT NULL REFERENCES public.providers(id) ON DELETE CASCADE,
    category_id         UUID NOT NULL REFERENCES public.service_categories(id),
    years_experience    INTEGER,
    description         TEXT,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_provider_category UNIQUE (provider_id, category_id)
);

CREATE INDEX idx_provider_services_provider_id ON public.provider_services(provider_id);
CREATE INDEX idx_provider_services_category_id ON public.provider_services(category_id);

-- ============================================================================
-- 7. SERVICE REQUESTS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.service_requests (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id             UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    category_id             UUID NOT NULL REFERENCES public.service_categories(id),
    title                   TEXT NOT NULL,
    description             TEXT NOT NULL,
    location                GEOGRAPHY(POINT, 4326) NOT NULL,
    address_line1           TEXT,
    address_city            TEXT,
    address_state           TEXT,
    address_zip             TEXT,
    preferred_date_start    DATE,
    preferred_date_end      DATE,
    preferred_time_slot     TEXT CHECK (preferred_time_slot IN ('morning', 'afternoon', 'evening', 'flexible')),
    budget_min              NUMERIC(10,2),
    budget_max              NUMERIC(10,2),
    status                  request_status_enum DEFAULT 'open',
    bid_window_end          TIMESTAMPTZ,
    awarded_bid_id          UUID,
    awarded_provider_id     UUID REFERENCES public.providers(id),
    scheduled_date          DATE,
    scheduled_time          TEXT,
    completed_at            TIMESTAMPTZ,
    cancelled_at            TIMESTAMPTZ,
    cancelled_by            UUID,
    cancellation_reason     TEXT,
    matching_radius_miles   INTEGER DEFAULT 25,
    total_bids              INTEGER DEFAULT 0,
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_service_requests_customer_id ON public.service_requests(customer_id, created_at DESC);
CREATE INDEX idx_service_requests_status ON public.service_requests(status)
    WHERE status NOT IN ('closed', 'cancelled');
CREATE INDEX idx_service_requests_category_id ON public.service_requests(category_id, status);
CREATE INDEX idx_service_requests_location ON public.service_requests USING GIST(location);

-- ============================================================================
-- 8. MATCHED PROVIDERS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.matched_providers (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id          UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    provider_id         UUID NOT NULL REFERENCES public.providers(id) ON DELETE CASCADE,
    composite_score     NUMERIC(6,4) NOT NULL,
    distance_miles      NUMERIC(6,2) NOT NULL,
    notified_at         TIMESTAMPTZ,
    notification_channels JSONB,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_matched_provider UNIQUE (request_id, provider_id)
);

CREATE INDEX idx_matched_providers_request_id ON public.matched_providers(request_id);
CREATE INDEX idx_matched_providers_provider_id ON public.matched_providers(provider_id);

-- ============================================================================
-- 9. BIDS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.bids (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id      UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    provider_id     UUID NOT NULL REFERENCES public.providers(id) ON DELETE CASCADE,
    amount          NUMERIC(10,2) NOT NULL,
    estimated_days  INTEGER,
    scope_of_work   TEXT NOT NULL,
    notes           TEXT,
    status          bid_status_enum DEFAULT 'pending',
    accepted_at     TIMESTAMPTZ,
    rejected_at     TIMESTAMPTZ,
    withdrawn_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_bid UNIQUE (request_id, provider_id)
);

CREATE INDEX idx_bids_request_id ON public.bids(request_id, created_at DESC);
CREATE INDEX idx_bids_provider_id ON public.bids(provider_id, status);

-- ============================================================================
-- 10. PAYMENTS TABLE (Stripe Integration)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.payments (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id                  UUID NOT NULL REFERENCES public.service_requests(id),
    bid_id                      UUID NOT NULL REFERENCES public.bids(id),
    customer_id                 UUID NOT NULL REFERENCES public.customers(id),
    provider_id                 UUID NOT NULL REFERENCES public.providers(id),
    stripe_payment_intent_id    TEXT NOT NULL UNIQUE,
    stripe_transfer_id          TEXT,
    amount_total                NUMERIC(10,2) NOT NULL,
    bid_amount                  NUMERIC(10,2) NOT NULL,
    customer_fee                NUMERIC(10,2) NOT NULL DEFAULT 0,
    platform_fee                NUMERIC(10,2) NOT NULL,
    provider_payout             NUMERIC(10,2) NOT NULL,
    stripe_processing_fee       NUMERIC(10,2),
    status                      payment_status_enum DEFAULT 'pending',
    payout_status               payout_status_enum DEFAULT 'pending',
    escrow_held_at              TIMESTAMPTZ,
    captured_at                 TIMESTAMPTZ,
    refunded_at                 TIMESTAMPTZ,
    refund_amount               NUMERIC(10,2),
    refund_reason               TEXT,
    payout_scheduled_at         TIMESTAMPTZ,
    payout_completed_at         TIMESTAMPTZ,
    created_at                  TIMESTAMPTZ DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_payments_request_id ON public.payments(request_id);
CREATE INDEX idx_payments_customer_id ON public.payments(customer_id);
CREATE INDEX idx_payments_provider_id ON public.payments(provider_id, payout_status);
CREATE INDEX idx_payments_status ON public.payments(status)
    WHERE status IN ('escrow_held', 'pending');

-- ============================================================================
-- 11. PAYMENT MILESTONES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.payment_milestones (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id      UUID NOT NULL REFERENCES public.payments(id) ON DELETE CASCADE,
    milestone_name  TEXT NOT NULL,
    amount          NUMERIC(10,2) NOT NULL,
    percentage      NUMERIC(5,2) NOT NULL,
    status          TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'released', 'disputed')),
    released_at     TIMESTAMPTZ,
    sort_order      INTEGER DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_payment_milestones_payment_id ON public.payment_milestones(payment_id);

-- ============================================================================
-- 12. REVIEWS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.reviews (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id              UUID NOT NULL REFERENCES public.service_requests(id),
    customer_id             UUID NOT NULL REFERENCES public.customers(id),
    provider_id             UUID NOT NULL REFERENCES public.providers(id),
    quality_score           INTEGER NOT NULL CHECK (quality_score BETWEEN 1 AND 5),
    timeliness_score        INTEGER NOT NULL CHECK (timeliness_score BETWEEN 1 AND 5),
    communication_score     INTEGER NOT NULL CHECK (communication_score BETWEEN 1 AND 5),
    composite_score         NUMERIC(3,2) NOT NULL,
    comment                 TEXT,
    would_book_again        BOOLEAN,
    provider_response       TEXT,
    provider_responded_at   TIMESTAMPTZ,
    is_visible              BOOLEAN DEFAULT false,
    is_flagged              BOOLEAN DEFAULT false,
    flagged_reason          TEXT,
    moderated_by            UUID,
    moderated_at            TIMESTAMPTZ,
    edit_window_end         TIMESTAMPTZ,
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_review UNIQUE (request_id, customer_id)
);

CREATE INDEX idx_reviews_provider_id ON public.reviews(provider_id, created_at DESC);
CREATE INDEX idx_reviews_customer_id ON public.reviews(customer_id, created_at DESC);

-- ============================================================================
-- 13. VERIFICATIONS TABLE (Background Checks, Licenses, Insurance)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.verifications (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id         UUID NOT NULL REFERENCES public.providers(id) ON DELETE CASCADE,
    check_type          TEXT NOT NULL CHECK (check_type IN (
                            'identity',
                            'criminal_background',
                            'trade_license',
                            'business_license',
                            'general_liability_insurance',
                            'workers_comp_insurance'
                        )),
    status              TEXT DEFAULT 'pending' CHECK (status IN (
                            'pending',
                            'in_progress',
                            'passed',
                            'failed',
                            'expired',
                            'requires_manual_review'
                        )),
    vendor              TEXT,
    vendor_ref_id       TEXT,
    document_url        TEXT,
    document_number     TEXT,
    issued_at           DATE,
    expires_at          DATE,
    verified_at         TIMESTAMPTZ,
    reviewed_by         UUID,
    reviewed_at         TIMESTAMPTZ,
    review_notes        TEXT,
    failure_reason      TEXT,
    reminder_30d_sent   BOOLEAN DEFAULT false,
    reminder_14d_sent   BOOLEAN DEFAULT false,
    reminder_7d_sent    BOOLEAN DEFAULT false,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_verifications_provider_id ON public.verifications(provider_id);
CREATE INDEX idx_verifications_check_type ON public.verifications(provider_id, check_type);
CREATE INDEX idx_verifications_expires_at ON public.verifications(expires_at, status)
    WHERE status = 'passed' AND expires_at IS NOT NULL;

-- ============================================================================
-- 14. DISPUTES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.disputes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id      UUID NOT NULL REFERENCES public.service_requests(id),
    payment_id      UUID REFERENCES public.payments(id),
    filed_by        UUID NOT NULL,
    filed_by_role   user_role_enum NOT NULL,
    reason          TEXT NOT NULL CHECK (reason IN (
                        'incomplete_work',
                        'poor_quality',
                        'no_show',
                        'overcharged',
                        'property_damage',
                        'provider_dispute',
                        'other'
                    )),
    description     TEXT NOT NULL,
    evidence_urls   TEXT[],
    status          TEXT DEFAULT 'open' CHECK (status IN (
                        'open',
                        'under_review',
                        'awaiting_response',
                        'resolved',
                        'escalated'
                    )),
    resolution      TEXT CHECK (resolution IN (
                        'full_refund',
                        'partial_refund',
                        'dismissed',
                        'provider_suspended',
                        'mutual_agreement'
                    )),
    resolution_notes TEXT,
    refund_amount   NUMERIC(10,2),
    resolved_by     UUID,
    resolved_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_disputes_request_id ON public.disputes(request_id);
CREATE INDEX idx_disputes_filed_by ON public.disputes(filed_by, created_at DESC);
CREATE INDEX idx_disputes_status ON public.disputes(status) WHERE status != 'resolved';

-- ============================================================================
-- 15. MESSAGES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id      UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    sender_id       UUID NOT NULL,
    sender_role     user_role_enum NOT NULL,
    content         TEXT NOT NULL,
    is_system       BOOLEAN DEFAULT false,
    read_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_messages_request_id ON public.messages(request_id, created_at DESC);
CREATE INDEX idx_messages_sender_id ON public.messages(sender_id, created_at DESC);

-- ============================================================================
-- 16. JOB PHOTOS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.job_photos (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id          UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    uploaded_by         UUID NOT NULL,
    uploaded_by_role    user_role_enum NOT NULL,
    photo_url           TEXT NOT NULL,
    phase               TEXT NOT NULL CHECK (phase IN ('before', 'during', 'after')),
    caption             TEXT,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_job_photos_request_id ON public.job_photos(request_id);

-- ============================================================================
-- 17. AUDIT LOG TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.audit_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id        UUID NOT NULL,
    actor_role      user_role_enum NOT NULL,
    action          TEXT NOT NULL,
    entity_type     TEXT NOT NULL,
    entity_id       UUID NOT NULL,
    changes         JSONB,
    ip_address      INET,
    user_agent      TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_log_entity ON public.audit_log(entity_type, entity_id, created_at DESC);
CREATE INDEX idx_audit_log_actor ON public.audit_log(actor_id, created_at DESC);

-- ============================================================================
-- 18. NOTIFICATIONS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.notifications (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL,
    user_role       user_role_enum NOT NULL,
    type            TEXT NOT NULL,
    title           TEXT NOT NULL,
    body            TEXT NOT NULL,
    data            JSONB,
    channels_sent   JSONB,
    read_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id ON public.notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_unread ON public.notifications(user_id, created_at DESC)
    WHERE read_at IS NULL;

-- ============================================================================
-- 19. MATERIALIZED VIEW: Provider Availability
-- ============================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS public.provider_availability AS
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
FROM public.providers p
LEFT JOIN public.service_requests sr ON sr.awarded_provider_id = p.id
WHERE p.verification_status = 'verified' AND p.is_active = true
GROUP BY p.id;

CREATE UNIQUE INDEX idx_mv_provider_availability ON public.provider_availability(provider_id);
CREATE INDEX idx_mv_provider_availability_location ON public.provider_availability USING GIST(service_location);

-- ============================================================================
-- 20. MATERIALIZED VIEW: Marketplace Health
-- ============================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS public.marketplace_health AS
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
    AVG(EXTRACT(EPOCH FROM (b.created_at - sr.created_at)) / 3600) AS avg_hours_to_first_bid
FROM public.service_requests sr
LEFT JOIN public.bids b ON b.request_id = sr.id
LEFT JOIN public.payments pay ON pay.request_id = sr.id
WHERE sr.created_at > NOW() - INTERVAL '90 days'
GROUP BY DATE_TRUNC('day', sr.created_at), sr.address_state;

CREATE INDEX idx_mv_marketplace_health ON public.marketplace_health(day DESC, market);

-- ============================================================================
-- 21. ROW-LEVEL SECURITY POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bids ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Customers can view their own profile and requests
CREATE POLICY customers_select_own ON public.customers
    FOR SELECT USING (auth.uid() = auth_user_id);

CREATE POLICY customers_update_own ON public.customers
    FOR UPDATE USING (auth.uid() = auth_user_id);

-- Customers can view service requests they created
CREATE POLICY customers_view_own_requests ON public.service_requests
    FOR SELECT USING (customer_id IN (
        SELECT id FROM public.customers WHERE auth_user_id = auth.uid()
    ));

-- Customers can view bids on their requests
CREATE POLICY customers_view_bids_on_own_requests ON public.bids
    FOR SELECT USING (request_id IN (
        SELECT id FROM public.service_requests
        WHERE customer_id IN (
            SELECT id FROM public.customers WHERE auth_user_id = auth.uid()
        )
    ));

-- Customers can view payments for their requests
CREATE POLICY customers_view_own_payments ON public.payments
    FOR SELECT USING (customer_id IN (
        SELECT id FROM public.customers WHERE auth_user_id = auth.uid()
    ));

-- Providers can view their own profile
CREATE POLICY providers_select_own ON public.providers
    FOR SELECT USING (auth.uid() = auth_user_id);

CREATE POLICY providers_update_own ON public.providers
    FOR UPDATE USING (auth.uid() = auth_user_id);

-- Providers can view available service requests (matching)
CREATE POLICY providers_view_matched_requests ON public.service_requests
    FOR SELECT USING (
        status NOT IN ('draft', 'cancelled', 'closed') AND
        id IN (
            SELECT request_id FROM public.matched_providers
            WHERE provider_id IN (
                SELECT id FROM public.providers WHERE auth_user_id = auth.uid()
            )
        )
    );

-- Providers can view their own bids
CREATE POLICY providers_view_own_bids ON public.bids
    FOR SELECT USING (provider_id IN (
        SELECT id FROM public.providers WHERE auth_user_id = auth.uid()
    ));

-- Providers can view payments for jobs they completed
CREATE POLICY providers_view_own_payments ON public.payments
    FOR SELECT USING (provider_id IN (
        SELECT id FROM public.providers WHERE auth_user_id = auth.uid()
    ));

-- Providers can view their own verifications
CREATE POLICY providers_view_own_verifications ON public.verifications
    FOR SELECT USING (provider_id IN (
        SELECT id FROM public.providers WHERE auth_user_id = auth.uid()
    ));

-- Service categories are public
ALTER TABLE public.service_categories DISABLE ROW LEVEL SECURITY;

-- Providers can view other providers (for competitive intelligence)
CREATE POLICY providers_view_providers ON public.providers
    FOR SELECT USING (true);

-- Customers can view verified providers
CREATE POLICY customers_view_providers ON public.providers
    FOR SELECT USING (verification_status = 'verified' AND is_active = true);

-- ============================================================================
-- 22. HELPER FUNCTIONS
-- ============================================================================

-- Function to calculate composite review score
CREATE OR REPLACE FUNCTION calculate_composite_score(
    quality INT,
    timeliness INT,
    communication INT
) RETURNS NUMERIC AS $$
BEGIN
    RETURN ROUND((quality * 0.5 + timeliness * 0.3 + communication * 0.2) / 5.0, 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to find nearby providers (PostGIS spatial matching)
CREATE OR REPLACE FUNCTION find_nearby_providers(
    request_longitude NUMERIC,
    request_latitude NUMERIC,
    category_id UUID,
    radius_miles INTEGER
)
RETURNS TABLE (
    provider_id UUID,
    business_name TEXT,
    tier provider_tier_enum,
    composite_rating NUMERIC,
    completion_rate NUMERIC,
    distance_miles NUMERIC,
    available_capacity INTEGER,
    composite_score NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.business_name,
        p.tier,
        p.composite_rating,
        p.completion_rate,
        ST_Distance(
            p.service_location,
            ST_SetSRID(ST_MakePoint(request_longitude, request_latitude), 4326)::geography
        ) / 1609.34 AS distance_miles,
        pa.available_capacity,
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
    FROM public.providers p
    LEFT JOIN public.provider_availability pa ON pa.provider_id = p.id
    LEFT JOIN public.provider_services ps ON ps.provider_id = p.id
    WHERE ps.category_id = find_nearby_providers.category_id
        AND ST_DWithin(
            p.service_location,
            ST_SetSRID(ST_MakePoint(request_longitude, request_latitude), 4326)::geography,
            radius_miles * 1609.34
        )
        AND p.verification_status = 'verified'
        AND p.is_active = true
        AND pa.available_capacity > 0
    ORDER BY composite_score DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- 23. TRIGGER FUNCTIONS FOR UPDATED_AT
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to all tables with updated_at
CREATE TRIGGER customers_updated_at BEFORE UPDATE ON public.customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER providers_updated_at BEFORE UPDATE ON public.providers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER service_requests_updated_at BEFORE UPDATE ON public.service_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER bids_updated_at BEFORE UPDATE ON public.bids
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER payments_updated_at BEFORE UPDATE ON public.payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER reviews_updated_at BEFORE UPDATE ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER verifications_updated_at BEFORE UPDATE ON public.verifications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER disputes_updated_at BEFORE UPDATE ON public.disputes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
