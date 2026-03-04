-- Verified Services Marketplace: Matching and Analytics Queries
-- PostGIS-based spatial matching engine

-- ============================================================================
-- 1. RADIUS-BASED PROVIDER SEARCH
-- ============================================================================
-- Find verified providers within radius, ordered by distance
-- Parameters: $1 = longitude, $2 = latitude, $3 = service_category_id, $4 = radius_miles

SELECT
    p.id,
    p.business_name,
    p.tier,
    p.composite_rating,
    p.completion_rate,
    p.avg_response_minutes,
    pa.available_capacity,
    ST_Distance(
        p.service_location,
        ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
    ) / 1609.34 AS distance_miles
FROM providers p
JOIN provider_services ps ON ps.provider_id = p.id
JOIN provider_availability pa ON pa.provider_id = p.id
WHERE ps.category_id = $3
    AND ST_DWithin(
        p.service_location,
        ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
        $4 * 1609.34  -- Convert miles to meters
    )
    AND p.verification_status = 'verified'
    AND p.is_active = true
    AND pa.available_capacity > 0
ORDER BY distance_miles ASC;

-- ============================================================================
-- 2. NEAREST-N PROVIDERS WITH COMPOSITE SCORING
-- ============================================================================
-- Find and rank top 10 providers for a request using weighted composite score
-- Parameters: $1 = longitude, $2 = latitude, $3 = service_category_id, $4 = radius_miles

SELECT
    p.id,
    p.business_name,
    p.tier,
    p.composite_rating,
    p.completion_rate,
    p.avg_response_minutes,
    p.updated_at,
    pa.available_capacity,
    ST_Distance(
        p.service_location,
        ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
    ) / 1609.34 AS distance_miles,
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
WHERE ps.category_id = $3
    AND ST_DWithin(
        p.service_location,
        ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
        $4 * 1609.34
    )
    AND p.verification_status = 'verified'
    AND p.is_active = true
    AND pa.available_capacity > 0
ORDER BY composite_score DESC
LIMIT 10;

-- ============================================================================
-- 3. MARKET COVERAGE ANALYSIS
-- ============================================================================
-- What percentage of metro area is covered by 3+ providers?
-- Parameters: $1 = address_state (market)

WITH market_requests AS (
    SELECT DISTINCT
        sr.location,
        sr.matching_radius_miles
    FROM service_requests sr
    WHERE sr.address_state = $1
        AND sr.created_at > NOW() - INTERVAL '30 days'
),
coverage_check AS (
    SELECT
        mr.location,
        COUNT(DISTINCT p.id) FILTER (
            WHERE ST_DWithin(
                p.service_location,
                mr.location,
                mr.matching_radius_miles * 1609.34
            )
            AND p.verification_status = 'verified'
            AND p.is_active = true
        ) AS provider_count
    FROM market_requests mr
    CROSS JOIN providers p
    GROUP BY mr.location
)
SELECT
    $1 AS market,
    COUNT(*) AS total_request_locations,
    COUNT(*) FILTER (WHERE provider_count >= 3) AS locations_with_3plus_providers,
    ROUND(
        COUNT(*) FILTER (WHERE provider_count >= 3)::NUMERIC / NULLIF(COUNT(*), 0) * 100,
        2
    ) AS coverage_percentage
FROM coverage_check;

-- ============================================================================
-- 4. SERVICE AREA OVERLAP DETECTION
-- ============================================================================
-- Find providers serving the same area (overlapping service radius)
-- Useful for identifying where we have good coverage vs. gaps
-- Parameters: $1 = address_state

SELECT
    p1.id AS provider_1_id,
    p1.business_name AS provider_1_name,
    p1.tier AS provider_1_tier,
    p2.id AS provider_2_id,
    p2.business_name AS provider_2_name,
    p2.tier AS provider_2_tier,
    ST_Distance(p1.service_location, p2.service_location) / 1609.34 AS distance_miles,
    ps1.category_id,
    sc.name AS category_name
FROM providers p1
JOIN providers p2 ON p1.id < p2.id
    AND ST_DWithin(p1.service_location, p2.service_location, 25 * 1609.34)
    AND p1.address_state = $1
    AND p2.address_state = $1
    AND p1.verification_status = 'verified'
    AND p2.verification_status = 'verified'
    AND p1.is_active = true
    AND p2.is_active = true
JOIN provider_services ps1 ON ps1.provider_id = p1.id
JOIN provider_services ps2 ON ps2.provider_id = p2.id
    AND ps1.category_id = ps2.category_id
JOIN service_categories sc ON sc.id = ps1.category_id
ORDER BY distance_miles ASC;

-- ============================================================================
-- 5. PROVIDER AVAILABILITY SNAPSHOT
-- ============================================================================
-- Quick snapshot of provider availability in a market
-- Parameters: $1 = address_state

SELECT
    p.id,
    p.business_name,
    p.tier,
    p.composite_rating,
    p.total_completed_jobs,
    pa.active_jobs,
    pa.available_capacity,
    ROUND(pa.active_jobs::NUMERIC / p.max_concurrent_jobs * 100, 0) AS utilization_pct,
    COUNT(DISTINCT ps.category_id) AS service_categories,
    string_agg(DISTINCT sc.name, ', ' ORDER BY sc.name) AS categories
FROM providers p
LEFT JOIN provider_availability pa ON pa.provider_id = p.id
LEFT JOIN provider_services ps ON ps.provider_id = p.id
LEFT JOIN service_categories sc ON sc.id = ps.category_id
WHERE p.address_state = $1
    AND p.verification_status = 'verified'
    AND p.is_active = true
GROUP BY p.id, p.business_name, p.tier, p.composite_rating, p.total_completed_jobs,
         p.max_concurrent_jobs, pa.active_jobs, pa.available_capacity
ORDER BY p.tier DESC, p.composite_rating DESC NULLS LAST;

-- ============================================================================
-- 6. REQUEST MATCHING PIPELINE
-- ============================================================================
-- Complete matching for a specific request
-- Parameters: $1 = request_id

WITH request_data AS (
    SELECT
        sr.id,
        sr.location,
        sr.category_id,
        sr.matching_radius_miles,
        sr.address_state,
        sr.created_at
    FROM service_requests sr
    WHERE sr.id = $1
),
candidates AS (
    SELECT
        p.id,
        p.business_name,
        p.tier,
        p.composite_rating,
        p.completion_rate,
        p.avg_response_minutes,
        p.updated_at,
        pa.available_capacity,
        ST_Distance(
            p.service_location,
            rd.location
        ) / 1609.34 AS distance_miles,
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
    FROM request_data rd
    CROSS JOIN providers p
    LEFT JOIN provider_availability pa ON pa.provider_id = p.id
    LEFT JOIN provider_services ps ON ps.provider_id = p.id
    WHERE ps.category_id = rd.category_id
        AND ST_DWithin(
            p.service_location,
            rd.location,
            rd.matching_radius_miles * 1609.34
        )
        AND p.verification_status = 'verified'
        AND p.is_active = true
        AND pa.available_capacity > 0
)
SELECT
    c.*,
    RANK() OVER (ORDER BY composite_score DESC) AS match_rank
FROM candidates c
ORDER BY composite_score DESC
LIMIT 10;

-- ============================================================================
-- 7. DAILY MATCHING METRICS
-- ============================================================================
-- Track matching performance over time
-- Parameters: $1 = date (YYYY-MM-DD)

SELECT
    DATE_TRUNC('hour', sr.created_at)::TIMESTAMP AS hour,
    sr.address_state AS market,
    COUNT(sr.id) AS requests_created,
    AVG(mp_count.match_count)::NUMERIC(5,2) AS avg_matched_providers,
    COUNT(sr.id) FILTER (WHERE mp_count.match_count >= 3)::NUMERIC /
        NULLIF(COUNT(sr.id), 0)::NUMERIC * 100 AS coverage_percentage
FROM service_requests sr
LEFT JOIN LATERAL (
    SELECT COUNT(*) AS match_count
    FROM matched_providers mp
    WHERE mp.request_id = sr.id
) mp_count ON true
WHERE sr.created_at::DATE = $1
GROUP BY DATE_TRUNC('hour', sr.created_at), sr.address_state
ORDER BY hour DESC, market;

-- ============================================================================
-- 8. PROVIDER EARNINGS DASHBOARD QUERY
-- ============================================================================
-- Parameters: $1 = provider_id

SELECT
    SUM(pay.provider_payout) FILTER (WHERE pay.payout_status = 'paid')::NUMERIC AS total_earned_cents,
    SUM(pay.provider_payout) FILTER (
        WHERE pay.status = 'captured' AND pay.payout_status = 'pending'
    )::NUMERIC AS pending_payout_cents,
    SUM(pay.provider_payout) FILTER (WHERE pay.status = 'escrow_held')::NUMERIC AS in_escrow_cents,
    COUNT(*) FILTER (WHERE pay.status = 'captured' AND pay.payout_status = 'paid') AS completed_payments,
    AVG(pay.provider_payout) FILTER (WHERE pay.payout_status = 'paid')::NUMERIC AS avg_job_payout_cents,
    AVG(pay.bid_amount) FILTER (WHERE pay.status = 'captured')::NUMERIC AS avg_bid_amount_cents,
    ROUND(
        SUM(pay.provider_payout) FILTER (WHERE pay.payout_status = 'paid')::NUMERIC /
        NULLIF(SUM(pay.bid_amount), 0) * 100,
        2
    ) AS effective_payout_percentage
FROM payments pay
WHERE pay.provider_id = $1;

-- ============================================================================
-- 9. MARKETPLACE HEALTH SNAPSHOT
-- ============================================================================
-- Overall marketplace metrics (queries materialized view)

SELECT
    mh.market,
    mh.day,
    mh.total_requests,
    mh.requests_with_3plus_bids,
    mh.bid_coverage_rate,
    mh.avg_bid_amount,
    mh.unique_providers_awarded,
    mh.daily_gmv,
    mh.avg_hours_to_first_bid
FROM marketplace_health mh
WHERE mh.day >= NOW()::DATE - INTERVAL '30 days'
ORDER BY mh.day DESC, mh.market;

-- ============================================================================
-- 10. GINI COEFFICIENT CALCULATION (EARNINGS DISTRIBUTION)
-- ============================================================================
-- Calculates earnings inequality across providers
-- Parameters: $1 = start_date, $2 = end_date

WITH period_earnings AS (
    SELECT
        p.id AS provider_id,
        SUM(pay.provider_payout) AS total_earnings
    FROM providers p
    LEFT JOIN payments pay ON pay.provider_id = p.id
        AND pay.payout_status = 'paid'
        AND pay.created_at >= $1
        AND pay.created_at < $2
    WHERE p.verification_status = 'verified'
        AND p.is_active = true
    GROUP BY p.id
    HAVING SUM(pay.provider_payout) > 0 OR COUNT(pay.id) = 0
),
sorted_earnings AS (
    SELECT
        provider_id,
        COALESCE(total_earnings, 0) AS earnings,
        ROW_NUMBER() OVER (ORDER BY COALESCE(total_earnings, 0) ASC) AS rank,
        COUNT(*) OVER () AS total_count
    FROM period_earnings
),
gini_calc AS (
    SELECT
        rank,
        earnings,
        total_count,
        SUM(earnings) OVER () AS total_earnings,
        (rank * earnings) AS weighted_earnings
    FROM sorted_earnings
)
SELECT
    (2.0 * SUM(weighted_earnings) / (total_count * total_earnings))
        - ((total_count + 1.0) / total_count) AS gini_coefficient,
    COUNT(*) AS provider_count,
    SUM(earnings) AS total_period_earnings
FROM gini_calc;
