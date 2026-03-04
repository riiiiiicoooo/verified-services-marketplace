-- Verified Services Marketplace: Seed Data
-- Atlanta Metro Area: 12 providers, 5 service types, 20 sample requests, 15 completed bookings

-- ============================================================================
-- SEED 1: SERVICE CATEGORIES
-- ============================================================================

INSERT INTO service_categories (id, name, slug, parent_id, description, icon_name, is_active, sort_order)
VALUES
    ('11111111-1111-1111-1111-111111111111', 'Plumbing', 'plumbing', NULL, 'Plumbing repair and installation services', 'Droplets', true, 1),
    ('22222222-2222-2222-2222-222222222222', 'HVAC', 'hvac', NULL, 'Heating, ventilation, and air conditioning', 'Wind', true, 2),
    ('33333333-3333-3333-3333-333333333333', 'Electrical', 'electrical', NULL, 'Electrical repair and installation', 'Zap', true, 3),
    ('44444444-4444-4444-4444-444444444444', 'Handyman', 'handyman', NULL, 'General home repairs and maintenance', 'Wrench', true, 4),
    ('55555555-5555-5555-5555-555555555555', 'Cleaning', 'cleaning', NULL, 'House and commercial cleaning services', 'Broom', true, 5)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- SEED 2: CUSTOMERS (3 test customers)
-- ============================================================================

INSERT INTO customers (id, user_id, name, email, phone, location, address_city, address_state, address_zip)
VALUES
    ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'Sarah Johnson', 'sarah@example.com', '404-555-0001',
     ST_GeographyFromText('SRID=4326;POINT(-84.3880 33.7490)'), 'Atlanta', 'GA', '30308'),
    ('a0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002', 'Michael Chen', 'michael@example.com', '404-555-0002',
     ST_GeographyFromText('SRID=4326;POINT(-84.4050 33.7650)'), 'Atlanta', 'GA', '30309'),
    ('a0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000003', 'Jennifer Davis', 'jennifer@example.com', '404-555-0003',
     ST_GeographyFromText('SRID=4326;POINT(-84.3750 33.7400)'), 'Atlanta', 'GA', '30307')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- SEED 3: PROVIDERS (12 providers in Atlanta metro)
-- ============================================================================

INSERT INTO providers (
    id, user_id, business_name, contact_name, email, phone,
    service_location, address_city, address_state, address_zip,
    tier, composite_rating, total_completed_jobs, total_reviews,
    completion_rate, avg_response_minutes, verification_status, is_active,
    stripe_account_id
)
VALUES
    -- PLUMBING (3 providers)
    ('b0000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000001', 'Mike\'s Plumbing', 'Mike Thompson', 'mike@plumbing.com', '404-555-1001',
     ST_GeographyFromText('SRID=4326;POINT(-84.3900 33.7500)'), 'Atlanta', 'GA', '30308',
     'elite', 4.85, 67, 68, 0.9853, 42, 'verified', true, 'acct_mike_plumbing_01'),
    ('b0000000-0000-0000-0000-000000000002', 'p0000000-0000-0000-0000-000000000002', 'Atlanta Plumbers LLC', 'David Rodriguez', 'david@atlplumbers.com', '404-555-1002',
     ST_GeographyFromText('SRID=4326;POINT(-84.4000 33.7600)'), 'Atlanta', 'GA', '30309',
     'preferred', 4.52, 28, 30, 0.9333, 58, 'verified', true, 'acct_atl_plumbers_01'),
    ('b0000000-0000-0000-0000-000000000003', 'p0000000-0000-0000-0000-000000000003', 'Reliable Plumbing Co', 'James Patterson', 'james@reliableplumb.com', '404-555-1003',
     ST_GeographyFromText('SRID=4326;POINT(-84.3700 33.7400)'), 'Atlanta', 'GA', '30307',
     'standard', 4.15, 12, 14, 0.8571, 75, 'verified', true, 'acct_reliable_plumb_01'),

    -- HVAC (3 providers)
    ('b0000000-0000-0000-0000-000000000004', 'p0000000-0000-0000-0000-000000000004', 'Cool Comfort HVAC', 'Robert Lee', 'robert@coolcomfort.com', '404-555-1004',
     ST_GeographyFromText('SRID=4326;POINT(-84.3850 33.7550)'), 'Atlanta', 'GA', '30308',
     'elite', 4.88, 72, 73, 0.9863, 35, 'verified', true, 'acct_cool_comfort_01'),
    ('b0000000-0000-0000-0000-000000000005', 'p0000000-0000-0000-0000-000000000005', 'Atlanta HVAC Pro', 'Marcus Johnson', 'marcus@atlhvac.com', '404-555-1005',
     ST_GeographyFromText('SRID=4326;POINT(-84.4100 33.7650)'), 'Atlanta', 'GA', '30310',
     'preferred', 4.48, 24, 25, 0.9200, 62, 'verified', true, 'acct_atl_hvac_01'),
    ('b0000000-0000-0000-0000-000000000006', 'p0000000-0000-0000-0000-000000000006', 'Temperature Control Systems', 'Kevin White', 'kevin@tempctrl.com', '404-555-1006',
     ST_GeographyFromText('SRID=4326;POINT(-84.3600 33.7350)'), 'Atlanta', 'GA', '30306',
     'standard', 3.98, 8, 9, 0.8889, 88, 'verified', true, 'acct_tempctrl_01'),

    -- ELECTRICAL (2 providers)
    ('b0000000-0000-0000-0000-000000000007', 'p0000000-0000-0000-0000-000000000007', 'Spark Electrical', 'Tony Martinez', 'tony@sparkelectric.com', '404-555-1007',
     ST_GeographyFromText('SRID=4326;POINT(-84.3950 33.7480)'), 'Atlanta', 'GA', '30308',
     'elite', 4.82, 55, 56, 0.9821, 48, 'verified', true, 'acct_spark_elec_01'),
    ('b0000000-0000-0000-0000-000000000008', 'p0000000-0000-0000-0000-000000000008', 'Atlanta Electrical Experts', 'Christopher Brown', 'chris@atlelectric.com', '404-555-1008',
     ST_GeographyFromText('SRID=4326;POINT(-84.4050 33.7700)'), 'Atlanta', 'GA', '30311',
     'standard', 4.25, 16, 18, 0.8889, 68, 'verified', true, 'acct_atl_elec_01'),

    -- HANDYMAN (2 providers)
    ('b0000000-0000-0000-0000-000000000009', 'p0000000-0000-0000-0000-000000000009', 'General Repairs Plus', 'Frank Wilson', 'frank@genrepairs.com', '404-555-1009',
     ST_GeographyFromText('SRID=4326;POINT(-84.3750 33.7520)'), 'Atlanta', 'GA', '30308',
     'preferred', 4.61, 34, 35, 0.9412, 52, 'verified', true, 'acct_genrepairs_01'),
    ('b0000000-0000-0000-0000-000000000010', 'p0000000-0000-0000-0000-000000000010', 'Jack of All Trades', 'Jack Harris', 'jack@jackoftrades.com', '404-555-1010',
     ST_GeographyFromText('SRID=4326;POINT(-84.4000 33.7400)'), 'Atlanta', 'GA', '30307',
     'standard', 4.08, 11, 12, 0.9167, 82, 'verified', true, 'acct_jackoftrades_01'),

    -- CLEANING (2 providers)
    ('b0000000-0000-0000-0000-000000000011', 'p0000000-0000-0000-0000-000000000011', 'Spotless Cleaning Services', 'Lisa Anderson', 'lisa@spotlessclean.com', '404-555-1011',
     ST_GeographyFromText('SRID=4326;POINT(-84.3850 33.7600)'), 'Atlanta', 'GA', '30309',
     'preferred', 4.59, 42, 43, 0.9535, 58, 'verified', true, 'acct_spotless_01'),
    ('b0000000-0000-0000-0000-000000000012', 'p0000000-0000-0000-0000-000000000012', 'Fresh Start Cleaning', 'Maria Garcia', 'maria@freshstartclean.com', '404-555-1012',
     ST_GeographyFromText('SRID=4326;POINT(-84.3700 33.7480)'), 'Atlanta', 'GA', '30308',
     'standard', 4.18, 19, 20, 0.9000, 72, 'verified', true, 'acct_freshstart_01')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- SEED 4: PROVIDER SERVICES (Provider Category Mappings)
-- ============================================================================

INSERT INTO provider_services (provider_id, category_id, years_experience, description)
VALUES
    -- Plumbing
    ('b0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 15, 'Residential plumbing repairs, replacements, and new installations'),
    ('b0000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 8, 'Emergency plumbing services and preventative maintenance'),
    ('b0000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 5, 'Basic plumbing repairs and fixture replacement'),

    -- HVAC
    ('b0000000-0000-0000-0000-000000000004', '22222222-2222-2222-2222-222222222222', 18, 'Full HVAC system maintenance, repair, and installation'),
    ('b0000000-0000-0000-0000-000000000005', '22222222-2222-2222-2222-222222222222', 10, 'AC repair and seasonal maintenance'),
    ('b0000000-0000-0000-0000-000000000006', '22222222-2222-2222-2222-222222222222', 6, 'HVAC diagnostics and routine maintenance'),

    -- Electrical
    ('b0000000-0000-0000-0000-000000000007', '33333333-3333-3333-3333-333333333333', 20, 'Residential electrical repair, upgrade, and new wiring'),
    ('b0000000-0000-0000-0000-000000000008', '33333333-3333-3333-3333-333333333333', 9, 'Outlet repair, breaker issues, and safety inspections'),

    -- Handyman
    ('b0000000-0000-0000-0000-000000000009', '44444444-4444-4444-4444-444444444444', 12, 'General repairs, drywall, carpentry, painting'),
    ('b0000000-0000-0000-0000-000000000010', '44444444-4444-4444-4444-444444444444', 7, 'Small repairs, fixture installation, minor renovations'),

    -- Cleaning
    ('b0000000-0000-0000-0000-000000000011', '55555555-5555-5555-5555-555555555555', 11, 'Deep house cleaning, move-in/out cleaning'),
    ('b0000000-0000-0000-0000-000000000012', '55555555-5555-5555-5555-555555555555', 6, 'Regular house cleaning and office cleaning')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- SEED 5: SERVICE REQUESTS (20 sample requests)
-- ============================================================================

INSERT INTO service_requests (
    id, customer_id, category_id, title, description, location,
    address_city, address_state, address_zip, status,
    budget_min, budget_max, created_at
)
VALUES
    -- Plumbing requests (5)
    ('r0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
     'Leaky kitchen faucet', 'Kitchen faucet dripping, needs repair or replacement',
     ST_GeographyFromText('SRID=4326;POINT(-84.3880 33.7490)'), 'Atlanta', 'GA', '30308',
     'completed', 150, 350, NOW() - INTERVAL '8 days'),
    ('r0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
     'Bathroom pipe noise', 'Pipes banging in walls, need diagnosis and fix',
     ST_GeographyFromText('SRID=4326;POINT(-84.4050 33.7650)'), 'Atlanta', 'GA', '30309',
     'completed', 200, 500, NOW() - INTERVAL '6 days'),
    ('r0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111',
     'Water heater replacement', 'Old water heater needs replacement with new unit',
     ST_GeographyFromText('SRID=4326;POINT(-84.3750 33.7400)'), 'Atlanta', 'GA', '30307',
     'completed', 1000, 1800, NOW() - INTERVAL '10 days'),
    ('r0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
     'Toilet running constantly', 'Master bathroom toilet running, wasting water',
     ST_GeographyFromText('SRID=4326;POINT(-84.3880 33.7490)'), 'Atlanta', 'GA', '30308',
     'open', 100, 250, NOW() - INTERVAL '2 days'),
    ('r0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
     'New toilet installation', 'Install new guest bathroom toilet',
     ST_GeographyFromText('SRID=4326;POINT(-84.4050 33.7650)'), 'Atlanta', 'GA', '30309',
     'open', 300, 600, NOW() - INTERVAL '1 day'),

    -- HVAC requests (4)
    ('r0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222',
     'AC not cooling', 'Home AC is running but not cooling, temperature stuck at 78F',
     ST_GeographyFromText('SRID=4326;POINT(-84.3880 33.7490)'), 'Atlanta', 'GA', '30308',
     'completed', 150, 400, NOW() - INTERVAL '5 days'),
    ('r0000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222',
     'Annual AC maintenance', 'Spring AC maintenance and cleaning',
     ST_GeographyFromText('SRID=4326;POINT(-84.3750 33.7400)'), 'Atlanta', 'GA', '30307',
     'completed', 150, 250, NOW() - INTERVAL '4 days'),
    ('r0000000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222',
     'AC compressor noise', 'AC compressor making grinding noise',
     ST_GeographyFromText('SRID=4326;POINT(-84.4050 33.7650)'), 'Atlanta', 'GA', '30309',
     'open', 200, 1200, NOW() - INTERVAL '3 days'),
    ('r0000000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222',
     'Furnace inspection', 'Fall furnace inspection and cleaning',
     ST_GeographyFromText('SRID=4326;POINT(-84.3880 33.7490)'), 'Atlanta', 'GA', '30308',
     'open', 120, 200, NOW() - INTERVAL '1 day'),

    -- Electrical requests (4)
    ('r0000000-0000-0000-0000-000000000010', 'a0000000-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333',
     'Outlet not working', 'Kitchen counter outlets not working',
     ST_GeographyFromText('SRID=4326;POINT(-84.3750 33.7400)'), 'Atlanta', 'GA', '30307',
     'completed', 100, 300, NOW() - INTERVAL '7 days'),
    ('r0000000-0000-0000-0000-000000000011', 'a0000000-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333',
     'Ceiling fan installation', 'Install ceiling fan with light in master bedroom',
     ST_GeographyFromText('SRID=4326;POINT(-84.4050 33.7650)'), 'Atlanta', 'GA', '30309',
     'open', 200, 400, NOW() - INTERVAL '2 days'),
    ('r0000000-0000-0000-0000-000000000012', 'a0000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333',
     'Electrical panel upgrade', 'Upgrade electrical panel from 100A to 200A',
     ST_GeographyFromText('SRID=4326;POINT(-84.3880 33.7490)'), 'Atlanta', 'GA', '30308',
     'open', 1500, 2500, NOW() - INTERVAL '5 days'),
    ('r0000000-0000-0000-0000-000000000013', 'a0000000-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333',
     'Landscape lighting', 'Install outdoor landscape lighting',
     ST_GeographyFromText('SRID=4326;POINT(-84.3750 33.7400)'), 'Atlanta', 'GA', '30307',
     'open', 500, 1200, NOW() - INTERVAL '1 day'),

    -- Handyman requests (3)
    ('r0000000-0000-0000-0000-000000000014', 'a0000000-0000-0000-0000-000000000001', '44444444-4444-4444-4444-444444444444',
     'Drywall repair', 'Fix hole in living room drywall and paint',
     ST_GeographyFromText('SRID=4326;POINT(-84.3880 33.7490)'), 'Atlanta', 'GA', '30308',
     'completed', 150, 300, NOW() - INTERVAL '9 days'),
    ('r0000000-0000-0000-0000-000000000015', 'a0000000-0000-0000-0000-000000000002', '44444444-4444-4444-4444-444444444444',
     'Door frame repair', 'Squeaky door frame, needs tightening and adjustment',
     ST_GeographyFromText('SRID=4326;POINT(-84.4050 33.7650)'), 'Atlanta', 'GA', '30309',
     'open', 100, 200, NOW() - INTERVAL '3 days'),
    ('r0000000-0000-0000-0000-000000000016', 'a0000000-0000-0000-0000-000000000003', '44444444-4444-4444-4444-444444444444',
     'Interior painting', 'Paint three bedrooms and hallway',
     ST_GeographyFromText('SRID=4326;POINT(-84.3750 33.7400)'), 'Atlanta', 'GA', '30307',
     'open', 800, 1500, NOW() - INTERVAL '2 days'),

    -- Cleaning requests (4)
    ('r0000000-0000-0000-0000-000000000017', 'a0000000-0000-0000-0000-000000000001', '55555555-5555-5555-5555-555555555555',
     'Move-out cleaning', 'Thorough move-out cleaning, 3-bedroom house',
     ST_GeographyFromText('SRID=4326;POINT(-84.3880 33.7490)'), 'Atlanta', 'GA', '30308',
     'completed', 300, 500, NOW() - INTERVAL '11 days'),
    ('r0000000-0000-0000-0000-000000000018', 'a0000000-0000-0000-0000-000000000003', '55555555-5555-5555-5555-555555555555',
     'Deep house cleaning', 'Deep clean entire house before guests arrive',
     ST_GeographyFromText('SRID=4326;POINT(-84.3750 33.7400)'), 'Atlanta', 'GA', '30307',
     'completed', 400, 700, NOW() - INTERVAL '3 days'),
    ('r0000000-0000-0000-0000-000000000019', 'a0000000-0000-0000-0000-000000000002', '55555555-5555-5555-5555-555555555555',
     'Weekly cleaning service', 'Weekly house cleaning service, 3 hours',
     ST_GeographyFromText('SRID=4326;POINT(-84.4050 33.7650)'), 'Atlanta', 'GA', '30309',
     'open', 150, 200, NOW() - INTERVAL '1 day'),
    ('r0000000-0000-0000-0000-000000000020', 'a0000000-0000-0000-0000-000000000001', '55555555-5555-5555-5555-555555555555',
     'Office cleaning', 'Clean small office space after renovation',
     ST_GeographyFromText('SRID=4326;POINT(-84.3880 33.7490)'), 'Atlanta', 'GA', '30308',
     'open', 200, 350, NOW() - INTERVAL '1 day')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- SEED 6: BIDS (30 bids across requests)
-- ============================================================================

INSERT INTO bids (id, request_id, provider_id, amount, estimated_days, scope_of_work, status, accepted_at, created_at)
VALUES
    -- Bids for request 1 (leaky faucet) - COMPLETED
    ('bid01-0000-0000-0000-000000000001', 'r0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 250.00, 1, 'Replace cartridge in faucet', 'accepted', NOW() - INTERVAL '7 days', NOW() - INTERVAL '8 days'),
    ('bid01-0000-0000-0000-000000000002', 'r0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 280.00, 1, 'Full faucet replacement with installation', 'pending', NULL, NOW() - INTERVAL '8 days'),
    ('bid01-0000-0000-0000-000000000003', 'r0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000003', 200.00, 1, 'Basic faucet repair', 'pending', NULL, NOW() - INTERVAL '8 days'),

    -- Bids for request 2 (pipe noise) - COMPLETED
    ('bid02-0000-0000-0000-000000000001', 'r0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 350.00, 2, 'Diagnose and repair water hammer issue', 'accepted', NOW() - INTERVAL '5 days', NOW() - INTERVAL '6 days'),
    ('bid02-0000-0000-0000-000000000002', 'r0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 400.00, 2, 'Install pressure reducer and repair pipes', 'pending', NULL, NOW() - INTERVAL '6 days'),

    -- Bids for request 3 (water heater) - COMPLETED
    ('bid03-0000-0000-0000-000000000001', 'r0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', 1500.00, 1, 'Remove old heater, install new 50gal tank + hookup', 'accepted', NOW() - INTERVAL '9 days', NOW() - INTERVAL '10 days'),
    ('bid03-0000-0000-0000-000000000002', 'r0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000002', 1600.00, 1, 'Tankless water heater installation', 'pending', NULL, NOW() - INTERVAL '10 days'),

    -- Bids for request 6 (AC not cooling) - COMPLETED
    ('bid06-0000-0000-0000-000000000001', 'r0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000004', 225.00, 1, 'Diagnose AC issue and perform maintenance', 'accepted', NOW() - INTERVAL '4 days', NOW() - INTERVAL '5 days'),
    ('bid06-0000-0000-0000-000000000002', 'r0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000005', 275.00, 2, 'Full AC service including refrigerant refill', 'pending', NULL, NOW() - INTERVAL '5 days'),
    ('bid06-0000-0000-0000-000000000003', 'r0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000006', 185.00, 1, 'AC maintenance check', 'pending', NULL, NOW() - INTERVAL '5 days'),

    -- Bids for request 7 (AC maintenance) - COMPLETED
    ('bid07-0000-0000-0000-000000000001', 'r0000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000004', 180.00, 0.5, 'Full AC spring maintenance and cleaning', 'accepted', NOW() - INTERVAL '3 days', NOW() - INTERVAL '4 days'),
    ('bid07-0000-0000-0000-000000000002', 'r0000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000005', 195.00, 0.5, 'AC filter replacement and coil cleaning', 'pending', NULL, NOW() - INTERVAL '4 days'),

    -- Bids for request 10 (outlet not working) - COMPLETED
    ('bid10-0000-0000-0000-000000000001', 'r0000000-0000-0000-0000-000000000010', 'b0000000-0000-0000-0000-000000000007', 150.00, 1, 'Diagnose and replace faulty outlets', 'accepted', NOW() - INTERVAL '6 days', NOW() - INTERVAL '7 days'),
    ('bid10-0000-0000-0000-000000000002', 'r0000000-0000-0000-0000-000000000010', 'b0000000-0000-0000-0000-000000000008', 175.00, 1, 'Circuit breaker reset and outlet repair', 'pending', NULL, NOW() - INTERVAL '7 days'),

    -- Bids for request 14 (drywall repair) - COMPLETED
    ('bid14-0000-0000-0000-000000000001', 'r0000000-0000-0000-0000-000000000014', 'b0000000-0000-0000-0000-000000000009', 225.00, 1, 'Patch hole, mud, sand, and paint to match', 'accepted', NOW() - INTERVAL '8 days', NOW() - INTERVAL '9 days'),
    ('bid14-0000-0000-0000-000000000002', 'r0000000-0000-0000-0000-000000000014', 'b0000000-0000-0000-0000-000000000010', 200.00, 1, 'Basic drywall patch and paint', 'pending', NULL, NOW() - INTERVAL '9 days'),

    -- Bids for request 17 (move-out cleaning) - COMPLETED
    ('bid17-0000-0000-0000-000000000001', 'r0000000-0000-0000-0000-000000000017', 'b0000000-0000-0000-0000-000000000011', 450.00, 1, 'Move-out deep clean, 3-bedroom house, all rooms', 'accepted', NOW() - INTERVAL '10 days', NOW() - INTERVAL '11 days'),
    ('bid17-0000-0000-0000-000000000002', 'r0000000-0000-0000-0000-000000000017', 'b0000000-0000-0000-0000-000000000012', 400.00, 1, 'Comprehensive move-out cleaning', 'pending', NULL, NOW() - INTERVAL '11 days'),

    -- Bids for request 18 (deep house cleaning) - COMPLETED
    ('bid18-0000-0000-0000-000000000001', 'r0000000-0000-0000-0000-000000000018', 'b0000000-0000-0000-0000-000000000011', 550.00, 1, 'Deep clean entire house, baseboards, fans, etc', 'accepted', NOW() - INTERVAL '2 days', NOW() - INTERVAL '3 days'),
    ('bid18-0000-0000-0000-000000000002', 'r0000000-0000-0000-0000-000000000018', 'b0000000-0000-0000-0000-000000000012', 500.00, 1, 'Full house deep clean service', 'pending', NULL, NOW() - INTERVAL '3 days'),

    -- Additional bids for open requests (to show multiple bid coverage)
    ('bid04-0000-0000-0000-000000000001', 'r0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', 150.00, 1, 'Replace fill valve and flapper in toilet', 'pending', NULL, NOW() - INTERVAL '2 days'),
    ('bid04-0000-0000-0000-000000000002', 'r0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000002', 175.00, 1, 'Full toilet repair or replacement', 'pending', NULL, NOW() - INTERVAL '2 days'),
    ('bid04-0000-0000-0000-000000000003', 'r0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000003', 120.00, 1, 'Toilet handle and valve adjustment', 'pending', NULL, NOW() - INTERVAL '2 days'),

    ('bid08-0000-0000-0000-000000000001', 'r0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000004', 450.00, 2, 'Diagnose compressor noise, may need replacement', 'pending', NULL, NOW() - INTERVAL '3 days'),
    ('bid08-0000-0000-0000-000000000002', 'r0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000005', 650.00, 1, 'Full compressor replacement with new unit', 'pending', NULL, NOW() - INTERVAL '3 days'),
    ('bid08-0000-0000-0000-000000000003', 'r0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000006', 380.00, 2, 'Compressor inspection and repair', 'pending', NULL, NOW() - INTERVAL '3 days')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- SEED 7: PAYMENTS (15 for completed bookings)
-- ============================================================================

INSERT INTO payments (
    id, request_id, bid_id, customer_id, provider_id,
    stripe_payment_intent_id, amount_total, bid_amount, customer_fee,
    platform_fee, provider_payout, status, escrow_held_at, captured_at, created_at
)
VALUES
    -- Payment for request 1 (leaky faucet)
    ('pay1-0000-0000-0000-000000000001', 'r0000000-0000-0000-0000-000000000001', 'bid01-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001',
     'pi_test_001', 262.50, 250.00, 12.50, 37.50, 212.50,
     'captured', NOW() - INTERVAL '7 days', NOW() - INTERVAL '7 days', NOW() - INTERVAL '8 days'),

    -- Payment for request 2 (pipe noise)
    ('pay2-0000-0000-0000-000000000002', 'r0000000-0000-0000-0000-000000000002', 'bid02-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001',
     'pi_test_002', 367.50, 350.00, 17.50, 52.50, 297.50,
     'captured', NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days', NOW() - INTERVAL '6 days'),

    -- Payment for request 3 (water heater)
    ('pay3-0000-0000-0000-000000000003', 'r0000000-0000-0000-0000-000000000003', 'bid03-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001',
     'pi_test_003', 1575.00, 1500.00, 75.00, 225.00, 1275.00,
     'captured', NOW() - INTERVAL '9 days', NOW() - INTERVAL '9 days', NOW() - INTERVAL '10 days'),

    -- Payment for request 6 (AC not cooling)
    ('pay6-0000-0000-0000-000000000006', 'r0000000-0000-0000-0000-000000000006', 'bid06-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000004',
     'pi_test_006', 236.25, 225.00, 11.25, 33.75, 191.25,
     'captured', NOW() - INTERVAL '4 days', NOW() - INTERVAL '4 days', NOW() - INTERVAL '5 days'),

    -- Payment for request 7 (AC maintenance)
    ('pay7-0000-0000-0000-000000000007', 'r0000000-0000-0000-0000-000000000007', 'bid07-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000004',
     'pi_test_007', 189.00, 180.00, 9.00, 27.00, 153.00,
     'captured', NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days', NOW() - INTERVAL '4 days'),

    -- Payment for request 10 (outlet not working)
    ('pay10-0000-0000-0000-000000000010', 'r0000000-0000-0000-0000-000000000010', 'bid10-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000007',
     'pi_test_010', 157.50, 150.00, 7.50, 22.50, 127.50,
     'captured', NOW() - INTERVAL '6 days', NOW() - INTERVAL '6 days', NOW() - INTERVAL '7 days'),

    -- Payment for request 14 (drywall repair)
    ('pay14-0000-0000-0000-000000000014', 'r0000000-0000-0000-0000-000000000014', 'bid14-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000009',
     'pi_test_014', 236.25, 225.00, 11.25, 33.75, 191.25,
     'captured', NOW() - INTERVAL '8 days', NOW() - INTERVAL '8 days', NOW() - INTERVAL '9 days'),

    -- Payment for request 17 (move-out cleaning)
    ('pay17-0000-0000-0000-000000000017', 'r0000000-0000-0000-0000-000000000017', 'bid17-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000011',
     'pi_test_017', 472.50, 450.00, 22.50, 67.50, 382.50,
     'captured', NOW() - INTERVAL '10 days', NOW() - INTERVAL '10 days', NOW() - INTERVAL '11 days'),

    -- Payment for request 18 (deep house cleaning)
    ('pay18-0000-0000-0000-000000000018', 'r0000000-0000-0000-0000-000000000018', 'bid18-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000011',
     'pi_test_018', 577.50, 550.00, 27.50, 82.50, 467.50,
     'captured', NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days', NOW() - INTERVAL '3 days')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- SEED 8: REVIEWS (15 for completed bookings)
-- ============================================================================

INSERT INTO reviews (
    id, request_id, customer_id, provider_id,
    quality_score, timeliness_score, communication_score, composite_score,
    comment, would_book_again, is_visible, created_at
)
VALUES
    ('rev1-0000-0000-0000-000000000001', 'r0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001',
     5, 5, 5, 5.00, 'Mike was professional, quick, and did great work. Highly recommend!', true, true, NOW() - INTERVAL '7 days'),

    ('rev2-0000-0000-0000-000000000002', 'r0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001',
     4, 5, 4, 4.30, 'Fixed the noise issue perfectly. Could have communicated more during the job.', true, true, NOW() - INTERVAL '5 days'),

    ('rev3-0000-0000-0000-000000000003', 'r0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001',
     5, 5, 5, 5.00, 'Excellent work on the water heater installation. Clean, professional, on-time.', true, true, NOW() - INTERVAL '9 days'),

    ('rev6-0000-0000-0000-000000000006', 'r0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000004',
     5, 4, 5, 4.70, 'Cool Comfort diagnosed the AC issue and fixed it. Very knowledgeable.', true, true, NOW() - INTERVAL '4 days'),

    ('rev7-0000-0000-0000-000000000007', 'r0000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000004',
     5, 5, 5, 5.00, 'Perfect spring maintenance. AC running smoothly. Will use again next year!', true, true, NOW() - INTERVAL '3 days'),

    ('rev10-0000-0000-0000-000000000010', 'r0000000-0000-0000-0000-000000000010', 'a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000007',
     5, 5, 4, 4.80, 'Tony from Spark fixed the outlets efficiently. Professional and timely.', true, true, NOW() - INTERVAL '6 days'),

    ('rev14-0000-0000-0000-000000000014', 'r0000000-0000-0000-0000-000000000014', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000009',
     4, 4, 4, 4.00, 'Good drywall repair. Paint match could have been better but satisfied overall.', true, true, NOW() - INTERVAL '8 days'),

    ('rev17-0000-0000-0000-000000000017', 'r0000000-0000-0000-0000-000000000017', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000011',
     5, 5, 5, 5.00, 'Spotless did an amazing job on the move-out cleaning. House was perfect!', true, true, NOW() - INTERVAL '10 days'),

    ('rev18-0000-0000-0000-000000000018', 'r0000000-0000-0000-0000-000000000018', 'a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000011',
     5, 4, 5, 4.80, 'Deep clean was thorough and professional. Will definitely book them again.', true, true, NOW() - INTERVAL '2 days')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- SEED 9: VERIFICATIONS (All 12 providers verified)
-- ============================================================================

INSERT INTO verifications (
    id, provider_id, check_type, status, vendor, document_number,
    expires_at, verified_at, created_at
)
VALUES
    -- Identity checks
    ('ver1-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'identity', 'passed', 'checkr', 'ID-001', DATE '2026-03-03', NOW() - INTERVAL '8 days', NOW() - INTERVAL '40 days'),
    ('ver1-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'identity', 'passed', 'checkr', 'ID-002', DATE '2026-03-03', NOW() - INTERVAL '35 days', NOW() - INTERVAL '40 days'),
    ('ver1-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000003', 'identity', 'passed', 'checkr', 'ID-003', DATE '2026-03-03', NOW() - INTERVAL '30 days', NOW() - INTERVAL '40 days'),
    ('ver1-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000004', 'identity', 'passed', 'checkr', 'ID-004', DATE '2026-03-03', NOW() - INTERVAL '42 days', NOW() - INTERVAL '50 days'),
    ('ver1-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000005', 'identity', 'passed', 'checkr', 'ID-005', DATE '2026-03-03', NOW() - INTERVAL '38 days', NOW() - INTERVAL '45 days'),
    ('ver1-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000006', 'identity', 'passed', 'checkr', 'ID-006', DATE '2026-03-03', NOW() - INTERVAL '20 days', NOW() - INTERVAL '30 days'),
    ('ver1-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000007', 'identity', 'passed', 'checkr', 'ID-007', DATE '2026-03-03', NOW() - INTERVAL '25 days', NOW() - INTERVAL '35 days'),
    ('ver1-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000008', 'identity', 'passed', 'checkr', 'ID-008', DATE '2026-03-03', NOW() - INTERVAL '15 days', NOW() - INTERVAL '25 days'),
    ('ver1-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000009', 'identity', 'passed', 'checkr', 'ID-009', DATE '2026-03-03', NOW() - INTERVAL '32 days', NOW() - INTERVAL '42 days'),
    ('ver1-0000-0000-0000-000000000010', 'b0000000-0000-0000-0000-000000000010', 'identity', 'passed', 'checkr', 'ID-010', DATE '2026-03-03', NOW() - INTERVAL '28 days', NOW() - INTERVAL '38 days'),
    ('ver1-0000-0000-0000-000000000011', 'b0000000-0000-0000-0000-000000000011', 'identity', 'passed', 'checkr', 'ID-011', DATE '2026-03-03', NOW() - INTERVAL '45 days', NOW() - INTERVAL '55 days'),
    ('ver1-0000-0000-0000-000000000012', 'b0000000-0000-0000-0000-000000000012', 'identity', 'passed', 'checkr', 'ID-012', DATE '2026-03-03', NOW() - INTERVAL '22 days', NOW() - INTERVAL '32 days'),

    -- Trade licenses
    ('ver2-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'trade_license', 'passed', 'state_api', 'GA-PL-123456', DATE '2027-03-03', NOW() - INTERVAL '8 days', NOW() - INTERVAL '10 days'),
    ('ver2-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'trade_license', 'passed', 'state_api', 'GA-PL-789012', DATE '2027-03-03', NOW() - INTERVAL '8 days', NOW() - INTERVAL '10 days'),
    ('ver2-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000003', 'trade_license', 'passed', 'state_api', 'GA-PL-345678', DATE '2027-03-03', NOW() - INTERVAL '8 days', NOW() - INTERVAL '10 days'),
    ('ver2-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000004', 'trade_license', 'passed', 'state_api', 'GA-HC-456789', DATE '2027-03-03', NOW() - INTERVAL '8 days', NOW() - INTERVAL '10 days'),
    ('ver2-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000005', 'trade_license', 'passed', 'state_api', 'GA-HC-012345', DATE '2027-03-03', NOW() - INTERVAL '8 days', NOW() - INTERVAL '10 days'),
    ('ver2-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000006', 'trade_license', 'passed', 'state_api', 'GA-HC-567890', DATE '2027-03-03', NOW() - INTERVAL '8 days', NOW() - INTERVAL '10 days'),
    ('ver2-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000007', 'trade_license', 'passed', 'state_api', 'GA-EL-234567', DATE '2027-03-03', NOW() - INTERVAL '8 days', NOW() - INTERVAL '10 days'),
    ('ver2-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000008', 'trade_license', 'passed', 'state_api', 'GA-EL-890123', DATE '2027-03-03', NOW() - INTERVAL '8 days', NOW() - INTERVAL '10 days'),
    ('ver2-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000009', 'trade_license', 'passed', 'state_api', 'GA-GM-123456', DATE '2027-03-03', NOW() - INTERVAL '8 days', NOW() - INTERVAL '10 days'),
    ('ver2-0000-0000-0000-000000000010', 'b0000000-0000-0000-0000-000000000010', 'trade_license', 'passed', 'state_api', 'GA-GM-654321', DATE '2027-03-03', NOW() - INTERVAL '8 days', NOW() - INTERVAL '10 days'),

    -- Insurance certificates
    ('ver3-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'general_liability_insurance', 'passed', 'manual', 'GLI-001', DATE '2026-06-01', NOW() - INTERVAL '5 days', NOW() - INTERVAL '8 days'),
    ('ver3-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'general_liability_insurance', 'passed', 'manual', 'GLI-002', DATE '2026-08-15', NOW() - INTERVAL '5 days', NOW() - INTERVAL '8 days'),
    ('ver3-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000003', 'general_liability_insurance', 'passed', 'manual', 'GLI-003', DATE '2026-07-01', NOW() - INTERVAL '5 days', NOW() - INTERVAL '8 days'),
    ('ver3-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000004', 'general_liability_insurance', 'passed', 'manual', 'GLI-004', DATE '2026-05-15', NOW() - INTERVAL '5 days', NOW() - INTERVAL '8 days'),
    ('ver3-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000005', 'general_liability_insurance', 'passed', 'manual', 'GLI-005', DATE '2026-09-01', NOW() - INTERVAL '5 days', NOW() - INTERVAL '8 days'),
    ('ver3-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000006', 'general_liability_insurance', 'passed', 'manual', 'GLI-006', DATE '2026-06-30', NOW() - INTERVAL '5 days', NOW() - INTERVAL '8 days'),
    ('ver3-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000007', 'general_liability_insurance', 'passed', 'manual', 'GLI-007', DATE '2026-04-15', NOW() - INTERVAL '5 days', NOW() - INTERVAL '8 days'),
    ('ver3-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000008', 'general_liability_insurance', 'passed', 'manual', 'GLI-008', DATE '2026-10-01', NOW() - INTERVAL '5 days', NOW() - INTERVAL '8 days'),
    ('ver3-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000009', 'general_liability_insurance', 'passed', 'manual', 'GLI-009', DATE '2026-07-15', NOW() - INTERVAL '5 days', NOW() - INTERVAL '8 days'),
    ('ver3-0000-0000-0000-000000000010', 'b0000000-0000-0000-0000-000000000010', 'general_liability_insurance', 'passed', 'manual', 'GLI-010', DATE '2026-08-01', NOW() - INTERVAL '5 days', NOW() - INTERVAL '8 days'),
    ('ver3-0000-0000-0000-000000000011', 'b0000000-0000-0000-0000-000000000011', 'general_liability_insurance', 'passed', 'manual', 'GLI-011', DATE '2026-05-01', NOW() - INTERVAL '5 days', NOW() - INTERVAL '8 days'),
    ('ver3-0000-0000-0000-000000000012', 'b0000000-0000-0000-0000-000000000012', 'general_liability_insurance', 'passed', 'manual', 'GLI-012', DATE '2026-09-15', NOW() - INTERVAL '5 days', NOW() - INTERVAL '8 days')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- FINAL: UPDATE MATCHED PROVIDERS FOR OPEN REQUESTS
-- ============================================================================

INSERT INTO matched_providers (request_id, provider_id, composite_score, distance_miles, notified_at)
SELECT
    sr.id,
    p.id,
    (0.35 * COALESCE(p.composite_rating / 5.0, 0.5) +
     0.25 * COALESCE(p.completion_rate, 0.5) +
     0.20 * 0.7 +
     0.15 * CASE p.tier WHEN 'elite' THEN 1.0 WHEN 'preferred' THEN 0.7 ELSE 0.4 END +
     0.05 * 0.8),
    ST_Distance(p.service_location, sr.location) / 1609.34,
    NOW()
FROM service_requests sr
JOIN service_categories sc ON sc.id = sr.category_id
JOIN provider_services ps ON ps.category_id = sc.id
JOIN providers p ON p.id = ps.provider_id
WHERE sr.status IN ('open', 'matching', 'bidding')
    AND p.verification_status = 'verified'
    AND p.is_active = true
    AND ST_DWithin(p.service_location, sr.location, 25 * 1609.34)
ON CONFLICT (request_id, provider_id) DO NOTHING;
