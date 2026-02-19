-- =====================================================
-- AUTO REPAIR SYSTEM - EXAMPLE QUERIES & TEST SCENARIOS
-- =====================================================

-- =====================================================
-- SAMPLE DATA INSERTION
-- =====================================================

-- Insert sample service providers (shops)
INSERT INTO public.service_providers (
    id, user_id, company_name, business_address, latitude, longitude,
    service_radius_km, is_verified, is_active
) VALUES 
(
    gen_random_uuid(), 
    gen_random_uuid(), -- Replace with actual user_id from auth.users
    'QuickFix Auto Repair',
    '123 Main Street, Manila, Philippines',
    14.5995,
    120.9842,
    15.0,
    true,
    true
),
(
    gen_random_uuid(),
    gen_random_uuid(),
    'SpeedyMech Services',
    '456 EDSA, Quezon City, Philippines', 
    14.6760,
    121.0437,
    20.0,
    true,
    true
);

-- Insert sample mechanics
INSERT INTO public.mechanics (
    id, user_id, shop_id, mechanic_name, status, latitude, longitude,
    specializations, experience_years, hourly_rate, is_accepting_requests
) VALUES
(
    gen_random_uuid(),
    gen_random_uuid(),
    (SELECT id FROM public.service_providers LIMIT 1), -- First shop
    'Juan Dela Cruz',
    'available',
    14.6000,
    120.9850,
    ARRAY['Engine Repair', 'Brake System', 'Electrical'],
    5,
    500.00,
    true
),
(
    gen_random_uuid(),
    gen_random_uuid(),
    (SELECT id FROM public.service_providers LIMIT 1 OFFSET 1), -- Second shop
    'Maria Santos',
    'available', 
    14.6800,
    121.0400,
    ARRAY['Transmission', 'Air Conditioning', 'Diagnostics'],
    8,
    750.00,
    true
),
(
    gen_random_uuid(),
    gen_random_uuid(),
    NULL, -- Independent mechanic
    'Pedro Reyes',
    'available',
    14.5800,
    120.9700,
    ARRAY['General Repair', 'Oil Change', 'Tire Replacement'],
    3,
    400.00,
    true
);

-- =====================================================
-- BUSINESS SCENARIO TEST QUERIES
-- =====================================================

-- SCENARIO 1: Customer chooses a specific shop
-- Should return only mechanics from that shop who are available

SELECT 
    'SCENARIO 1: Shop-Specific Request' as scenario,
    m.*
FROM get_available_mechanics_in_shop(
    (SELECT id FROM public.service_providers WHERE company_name = 'QuickFix Auto Repair')
) m;

-- SCENARIO 2: Customer doesn't choose a shop (broadcast mode)
-- Should return nearest available mechanic regardless of shop

SELECT 
    'SCENARIO 2: Nearest Available Mechanic' as scenario,
    m.*
FROM get_nearest_available_mechanic(
    14.5995, -- Customer location: Manila coordinates
    120.9842,
    25.0 -- Search within 25km
) m;

-- SCENARIO 3: Test atomic request acceptance
-- Create a sample request first, then test acceptance

DO $$
DECLARE
    test_request_id uuid := gen_random_uuid();
    test_customer_id uuid := gen_random_uuid();
    nearest_mechanic_id uuid;
    acceptance_result record;
BEGIN
    -- Insert a test customer (in real app, this would be from auth.users)
    INSERT INTO auth.users (id, email) VALUES (test_customer_id, 'test.customer@example.com')
    ON CONFLICT (id) DO NOTHING;
    
    -- Create a test service request
    INSERT INTO public.service_requests (
        id, customer_id, title, description, service_type,
        pickup_latitude, pickup_longitude, pickup_address, status
    ) VALUES (
        test_request_id,
        test_customer_id,
        'Engine won''t start',
        'Car engine cranks but won''t turn over. Possible fuel pump issue.',
        'Engine Diagnostics',
        14.5995,
        120.9842,
        'Ayala Avenue, Makati City',
        'pending'
    );
    
    -- Get nearest available mechanic
    SELECT mechanic_id INTO nearest_mechanic_id
    FROM get_nearest_available_mechanic(14.5995, 120.9842, 25.0)
    LIMIT 1;
    
    IF nearest_mechanic_id IS NOT NULL THEN
        -- Test atomic acceptance
        SELECT * INTO acceptance_result
        FROM accept_service_request(test_request_id, nearest_mechanic_id);
        
        RAISE NOTICE 'SCENARIO 3: Request Acceptance Result';
        RAISE NOTICE 'Success: %, Message: %', acceptance_result.success, acceptance_result.message;
    ELSE
        RAISE NOTICE 'SCENARIO 3: No available mechanics found for testing';
    END IF;
END $$;

-- SCENARIO 4: Broadcast request to multiple mechanics
-- Test the broadcasting system

DO $$
DECLARE
    test_request_id uuid := gen_random_uuid();
    test_customer_id uuid := gen_random_uuid();
    broadcast_result record;
BEGIN
    -- Insert test customer
    INSERT INTO auth.users (id, email) VALUES (test_customer_id, 'broadcast.customer@example.com')
    ON CONFLICT (id) DO NOTHING;
    
    -- Create broadcast request
    INSERT INTO public.service_requests (
        id, customer_id, title, description, service_type,
        pickup_latitude, pickup_longitude, pickup_address, 
        status, request_type
    ) VALUES (
        test_request_id,
        test_customer_id,
        'Roadside Assistance Needed',
        'Flat tire on highway, need immediate help',
        'Tire Replacement',
        14.6200, -- Different location for testing
        120.9900,
        'EDSA, Mandaluyong City',
        'pending',
        'broadcast'
    );
    
    -- Test broadcasting
    SELECT * INTO broadcast_result
    FROM broadcast_service_request(test_request_id, 15.0, 5);
    
    RAISE NOTICE 'SCENARIO 4: Broadcast Result';
    RAISE NOTICE 'Success: %, Mechanics Notified: %, Message: %', 
        broadcast_result.success, broadcast_result.mechanics_notified, broadcast_result.message;
        
    -- Show routing entries created
    RAISE NOTICE 'Routing entries created:';
    FOR broadcast_result IN 
        SELECT 
            m.mechanic_name,
            rr.distance_km,
            rr.estimated_arrival_minutes
        FROM public.request_routing rr
        JOIN public.mechanics m ON m.id = rr.mechanic_id
        WHERE rr.request_id = test_request_id
        ORDER BY rr.distance_km
    LOOP
        RAISE NOTICE '  - %: %.2f km, ~% minutes', 
            broadcast_result.mechanic_name, 
            broadcast_result.distance_km, 
            broadcast_result.estimated_arrival_minutes;
    END LOOP;
END $$;

-- =====================================================
-- ADVANCED QUERY EXAMPLES
-- =====================================================

-- Query: Find all shops within radius with available mechanics count
CREATE OR REPLACE VIEW shops_with_availability AS
SELECT 
    sp.id,
    sp.company_name,
    sp.business_address,
    sp.latitude,
    sp.longitude,
    sp.rating,
    COUNT(m.id) FILTER (WHERE m.status = 'available') as available_mechanics,
    COUNT(m.id) as total_mechanics,
    sp.service_radius_km
FROM public.service_providers sp
LEFT JOIN public.mechanics m ON m.shop_id = sp.id AND m.is_accepting_requests = true
WHERE sp.is_active = true
GROUP BY sp.id, sp.company_name, sp.business_address, sp.latitude, sp.longitude, sp.rating, sp.service_radius_km;

-- Query: Get shops within radius of customer location
CREATE OR REPLACE FUNCTION get_nearby_shops_with_mechanics(
    customer_lat numeric,
    customer_lng numeric,
    radius_km numeric DEFAULT 20.0
)
RETURNS TABLE (
    shop_id uuid,
    shop_name varchar,
    shop_address text,
    distance_km numeric,
    available_mechanics bigint,
    total_mechanics bigint,
    shop_rating numeric
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        swa.id,
        swa.company_name,
        swa.business_address,
        ROUND(
            ST_Distance(
                ST_SetSRID(ST_MakePoint(customer_lng, customer_lat), 4326),
                ST_SetSRID(ST_MakePoint(swa.longitude, swa.latitude), 4326)
            ) / 1000, 2
        ) as distance_km,
        swa.available_mechanics,
        swa.total_mechanics,
        swa.rating
    FROM shops_with_availability swa
    WHERE ST_DWithin(
        ST_SetSRID(ST_MakePoint(customer_lng, customer_lat), 4326),
        ST_SetSRID(ST_MakePoint(swa.longitude, swa.latitude), 4326),
        radius_km * 1000
    )
    AND swa.available_mechanics > 0
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql;

-- Query: Get mechanic performance statistics
CREATE OR REPLACE VIEW mechanic_performance_stats AS
SELECT 
    m.id,
    m.mechanic_name,
    m.status,
    sp.company_name as shop_name,
    m.rating,
    m.total_completed_jobs,
    m.experience_years,
    m.hourly_rate,
    CASE 
        WHEN m.total_completed_jobs > 0 THEN m.rating 
        ELSE 0 
    END as performance_score,
    m.specializations,
    m.is_accepting_requests
FROM public.mechanics m
LEFT JOIN public.service_providers sp ON sp.id = m.shop_id;

-- Query: Real-time mechanic tracking for active requests
CREATE OR REPLACE FUNCTION get_active_request_tracking(
    request_id_param uuid
)
RETURNS TABLE (
    request_id uuid,
    customer_id uuid,
    mechanic_id uuid,
    mechanic_name varchar,
    shop_name varchar,
    current_status varchar,
    mechanic_lat numeric,
    mechanic_lng numeric,
    customer_lat numeric,
    customer_lng numeric,
    distance_to_customer_km numeric,
    estimated_arrival_minutes integer
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sr.id,
        sr.customer_id,
        m.id,
        m.mechanic_name,
        COALESCE(sp.company_name, 'Independent') as shop_name,
        sr.status,
        m.latitude,
        m.longitude,
        sr.pickup_latitude,
        sr.pickup_longitude,
        ROUND(
            ST_Distance(
                ST_SetSRID(ST_MakePoint(m.longitude, m.latitude), 4326),
                sr.location
            ) / 1000, 2
        ) as distance_to_customer_km,
        ROUND(
            (ST_Distance(
                ST_SetSRID(ST_MakePoint(m.longitude, m.latitude), 4326),
                sr.location
            ) / 1000) * 2 + 5
        )::integer as estimated_arrival_minutes
    FROM public.service_requests sr
    JOIN public.mechanics m ON m.id = sr.accepted_by
    LEFT JOIN public.service_providers sp ON sp.id = m.shop_id
    WHERE sr.id = request_id_param
    AND sr.status IN ('accepted', 'assigned', 'in_progress');
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PERFORMANCE MONITORING QUERIES
-- =====================================================

-- Query: System performance overview
SELECT 
    'Total Shops' as metric,
    COUNT(*) as value
FROM public.service_providers
WHERE is_active = true

UNION ALL

SELECT 
    'Total Mechanics' as metric,
    COUNT(*) as value
FROM public.mechanics

UNION ALL

SELECT 
    'Available Mechanics' as metric,
    COUNT(*) as value
FROM public.mechanics
WHERE status = 'available' AND is_accepting_requests = true

UNION ALL

SELECT 
    'Active Requests' as metric,
    COUNT(*) as value
FROM public.service_requests
WHERE status IN ('pending', 'broadcasting', 'accepted', 'assigned', 'in_progress')

UNION ALL

SELECT 
    'Completed Today' as metric,
    COUNT(*) as value
FROM public.service_requests
WHERE status = 'completed' 
AND completed_at >= CURRENT_DATE;

-- Query: Average response times
SELECT 
    'Average Acceptance Time (minutes)' as metric,
    ROUND(AVG(EXTRACT(EPOCH FROM (accepted_at - created_at)) / 60), 2) as value
FROM public.service_requests
WHERE accepted_at IS NOT NULL
AND created_at >= CURRENT_DATE - INTERVAL '7 days'

UNION ALL

SELECT 
    'Average Completion Time (hours)' as metric,
    ROUND(AVG(EXTRACT(EPOCH FROM (completed_at - accepted_at)) / 3600), 2) as value
FROM public.service_requests
WHERE completed_at IS NOT NULL 
AND accepted_at IS NOT NULL
AND created_at >= CURRENT_DATE - INTERVAL '7 days';

-- =====================================================
-- CLEANUP FUNCTIONS
-- =====================================================

-- Function to clean up expired requests
CREATE OR REPLACE FUNCTION cleanup_expired_requests()
RETURNS integer AS $$
DECLARE
    cleaned_count integer;
BEGIN
    UPDATE public.service_requests
    SET status = 'expired'
    WHERE status = 'pending'
    AND expires_at < now()
    AND created_at < now() - INTERVAL '2 hours';
    
    GET DIAGNOSTICS cleaned_count = ROW_COUNT;
    
    -- Clean up associated routing entries
    DELETE FROM public.request_routing
    WHERE request_id IN (
        SELECT id FROM public.service_requests 
        WHERE status = 'expired'
    );
    
    RETURN cleaned_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- USAGE EXAMPLES
-- =====================================================

/*
-- Example 1: Customer searches for nearby shops
SELECT * FROM get_nearby_shops_with_mechanics(14.5995, 120.9842, 15.0);

-- Example 2: Get available mechanics in specific shop
SELECT * FROM get_available_mechanics_in_shop('shop-uuid-here');

-- Example 3: Find nearest mechanic (no shop preference)
SELECT * FROM get_nearest_available_mechanic(14.5995, 120.9842, 25.0);

-- Example 4: Accept a request atomically
SELECT * FROM accept_service_request('request-uuid', 'mechanic-uuid');

-- Example 5: Broadcast emergency request
SELECT * FROM broadcast_service_request('request-uuid', 30.0, 10);

-- Example 6: Track active request
SELECT * FROM get_active_request_tracking('request-uuid');

-- Example 7: Clean up expired requests
SELECT cleanup_expired_requests() as expired_requests_cleaned;

-- Example 8: Performance monitoring
SELECT * FROM mechanic_performance_stats 
WHERE status = 'available' 
ORDER BY performance_score DESC;
*/