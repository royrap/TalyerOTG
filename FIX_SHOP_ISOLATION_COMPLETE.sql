-- =========================================================================
-- FIX: Shop-Based Request Isolation
-- =========================================================================
-- PROBLEMA: 
--   Customer pinili ang Shop A → dapat LAHAT ng mechanic sa Shop A lang makakakita
--   Shop B mechanics → HINDI dapat makita ang request
--
-- SOLUSYON:
--   1. Gamitin ang shop_id column sa service_requests
--   2. I-filter ang mechanics based sa shop_mechanics table
--   3. Siguruhing SHOP ISOLATION ay nakapataw
-- =========================================================================

-- =========================================================================
-- STEP 1: Update get_nearby_requests_for_mechanic function
-- =========================================================================
-- This ensures ONLY mechanics from the selected shop can see shop-based requests

DROP FUNCTION IF EXISTS get_nearby_requests_for_mechanic(UUID, NUMERIC, NUMERIC, NUMERIC);

CREATE OR REPLACE FUNCTION get_nearby_requests_for_mechanic(
    p_mechanic_id UUID,
    p_mechanic_lat NUMERIC,
    p_mechanic_lng NUMERIC,
    p_max_distance_km NUMERIC DEFAULT 50.0
)
RETURNS TABLE (
    request_id UUID,
    customer_id UUID,
    title VARCHAR,
    description TEXT,
    pickup_latitude NUMERIC,
    pickup_longitude NUMERIC,
    pickup_address TEXT,
    service_type VARCHAR,
    priority VARCHAR,
    status VARCHAR,
    created_at TIMESTAMPTZ,
    estimated_price NUMERIC,
    request_type TEXT,
    distance_km NUMERIC,
    estimated_arrival_minutes INTEGER,
    urgency_level TEXT,
    customer_first_name VARCHAR,
    customer_last_name VARCHAR,
    customer_phone VARCHAR,
    customer_profile_image TEXT,
    is_eligible BOOLEAN,
    shop_id UUID  -- Added to show which shop the request is for
) AS $$
BEGIN
    RETURN QUERY
    WITH distance_calc AS (
        SELECT 
            sr.id,
            sr.customer_id,
            sr.title,
            sr.description,
            sr.pickup_latitude,
            sr.pickup_longitude,
            sr.pickup_address,
            sr.service_type,
            sr.priority,
            sr.status,
            sr.created_at,
            sr.estimated_price,
            sr.request_type,
            sr.shop_id,  -- USE SHOP_ID (not preferred_shop_id)
            sr.can_accept_by_any_mechanic,
            up.first_name as customer_first_name,
            up.last_name as customer_last_name,
            up.phone_number as customer_phone,
            up.profile_image_url as customer_profile_image,
            -- SAFE Haversine formula with LEAST/GREATEST to prevent acos domain errors
            (
                6371 * acos(
                    LEAST(1.0, GREATEST(-1.0,
                        cos(radians(p_mechanic_lat)) * 
                        cos(radians(sr.pickup_latitude)) * 
                        cos(radians(sr.pickup_longitude) - radians(p_mechanic_lng)) + 
                        sin(radians(p_mechanic_lat)) * 
                        sin(radians(sr.pickup_latitude))
                    ))
                )
            ) AS distance_km,
            -- Calculate urgency based on how long the request has been pending
            CASE 
                WHEN EXTRACT(HOUR FROM (NOW() - sr.created_at)) >= 2 THEN 'high'
                WHEN EXTRACT(HOUR FROM (NOW() - sr.created_at)) >= 1 THEN 'medium'
                ELSE 'normal'
            END AS urgency_level
        FROM service_requests sr
        INNER JOIN user_profiles up ON sr.customer_id = up.id
        WHERE 
            sr.status IN ('pending', 'awaiting_payment', 'ready_to_assign')
            AND sr.pickup_latitude IS NOT NULL 
            AND sr.pickup_longitude IS NOT NULL
            AND sr.assigned_mechanic_id IS NULL
            AND sr.accepted_by IS NULL
    ),
    filtered_requests AS (
        SELECT 
            dc.*,
            -- Estimate arrival time based on distance
            ROUND((dc.distance_km / 30.0 * 60) + 5)::INTEGER AS estimated_arrival_minutes,
            -- ✅ SHOP ISOLATION: Check eligibility based on request type and mechanic's shop
            CASE 
                -- For broadcast/direct mechanic requests (any mechanic can see)
                WHEN dc.request_type IN ('broadcast', 'direct_mechanic') AND dc.can_accept_by_any_mechanic = true THEN
                    EXISTS (
                        SELECT 1 FROM mechanic_availability_status mas
                        WHERE mas.mechanic_id = p_mechanic_id
                        AND mas.current_status = 'available'
                        AND mas.is_accepting_requests = true
                    )
                
                -- ✅ FOR SHOP-BASED REQUESTS: STRICT SHOP ISOLATION
                -- Only mechanics who belong to the SELECTED SHOP can see the request
                WHEN dc.request_type = 'shop_based' AND dc.shop_id IS NOT NULL THEN
                    (
                        -- ✅ Check if mechanic works at THIS SPECIFIC SHOP
                        EXISTS (
                            SELECT 1 FROM shop_mechanics sm
                            WHERE sm.mechanic_id = p_mechanic_id
                            AND sm.shop_id = dc.shop_id  -- MUST match request's shop_id
                            AND sm.is_active = true
                        )
                        AND
                        -- Check if mechanic is available
                        EXISTS (
                            SELECT 1 FROM mechanic_availability_status mas
                            WHERE mas.mechanic_id = p_mechanic_id
                            AND mas.current_status = 'available'
                            AND mas.is_accepting_requests = true
                        )
                    )
                
                ELSE false
            END AS is_eligible
        FROM distance_calc dc
        WHERE dc.distance_km <= p_max_distance_km
    )
    SELECT 
        fr.id::UUID as request_id,
        fr.customer_id::UUID,
        fr.title::VARCHAR,
        fr.description::TEXT,
        fr.pickup_latitude::NUMERIC,
        fr.pickup_longitude::NUMERIC,
        fr.pickup_address::TEXT,
        fr.service_type::VARCHAR,
        fr.priority::VARCHAR,
        fr.status::VARCHAR,
        fr.created_at::TIMESTAMPTZ,
        fr.estimated_price::NUMERIC,
        fr.request_type::TEXT,
        fr.distance_km::NUMERIC,
        fr.estimated_arrival_minutes::INTEGER,
        fr.urgency_level::TEXT,
        fr.customer_first_name::VARCHAR,
        fr.customer_last_name::VARCHAR,
        fr.customer_phone::VARCHAR,
        fr.customer_profile_image::TEXT,
        fr.is_eligible::BOOLEAN,
        fr.shop_id::UUID  -- Return shop_id for visibility
    FROM filtered_requests fr
    WHERE fr.is_eligible = true
    ORDER BY 
        -- Sort by urgency first, then by distance
        CASE fr.urgency_level 
            WHEN 'high' THEN 1
            WHEN 'medium' THEN 2
            ELSE 3
        END,
        fr.distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_nearby_requests_for_mechanic(UUID, NUMERIC, NUMERIC, NUMERIC) TO authenticated;

-- =========================================================================
-- STEP 2: Ensure shop_id is set correctly when request is created
-- =========================================================================
-- Make sure shop_id is populated when customer selects a shop

-- Check if shop_id column exists
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'service_requests' 
        AND column_name = 'shop_id'
    ) THEN
        ALTER TABLE service_requests ADD COLUMN shop_id UUID REFERENCES shops(id);
        RAISE NOTICE '✅ Added shop_id column to service_requests';
    ELSE
        RAISE NOTICE 'ℹ️ shop_id column already exists';
    END IF;
END $$;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_service_requests_shop_id ON service_requests(shop_id);

-- =========================================================================
-- STEP 3: Update existing requests to set shop_id from preferred_shop_id
-- =========================================================================
-- For any existing shop-based requests without shop_id

UPDATE service_requests
SET shop_id = preferred_shop_id
WHERE request_type = 'shop_based'
AND shop_id IS NULL
AND preferred_shop_id IS NOT NULL
AND status IN ('pending', 'awaiting_payment', 'ready_to_assign');

-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

-- Check function exists and uses shop_id
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Function exists'
        ELSE '❌ Function missing'
    END as function_status
FROM pg_proc
WHERE proname = 'get_nearby_requests_for_mechanic';

-- Verify shop isolation logic
SELECT 
    CASE 
        WHEN pg_get_functiondef(oid) LIKE '%sm.shop_id = dc.shop_id%' THEN '✅ Shop isolation active'
        ELSE '❌ Shop isolation NOT active'
    END as shop_isolation_status
FROM pg_proc
WHERE proname = 'get_nearby_requests_for_mechanic';

-- Show current shop-based requests
SELECT 
    sr.id,
    sr.request_type,
    sr.shop_id,
    sr.status,
    s.shop_name,
    COUNT(DISTINCT sm.mechanic_id) as mechanics_in_shop
FROM service_requests sr
LEFT JOIN shops s ON sr.shop_id = s.id
LEFT JOIN shop_mechanics sm ON sm.shop_id = sr.shop_id AND sm.is_active = true
WHERE sr.request_type = 'shop_based'
AND sr.status IN ('pending', 'awaiting_payment', 'ready_to_assign')
GROUP BY sr.id, sr.request_type, sr.shop_id, sr.status, s.shop_name
ORDER BY sr.created_at DESC;

-- =========================================================================
-- TESTING
-- =========================================================================
/*
TO TEST SHOP ISOLATION:

1. Create a request as customer with Shop A selected
2. Login as Mechanic 1 (belongs to Shop A) → Should see request ✅
3. Login as Mechanic 2 (belongs to Shop B) → Should NOT see request ❌

TEST QUERY:
-- Replace with actual IDs
SELECT * FROM get_nearby_requests_for_mechanic(
    'MECHANIC_1_ID'::uuid,  -- Mechanic from Shop A
    14.6507,  -- Mechanic latitude
    121.0494,  -- Mechanic longitude
    50.0  -- Max distance
);

SELECT * FROM get_nearby_requests_for_mechanic(
    'MECHANIC_2_ID'::uuid,  -- Mechanic from Shop B
    14.6507,
    121.0494,
    50.0
);
*/

-- =========================================================================
-- DEPLOYMENT NOTES
-- =========================================================================
/*
WHAT WAS FIXED:

1. ✅ Changed from preferred_shop_id to shop_id
   - shop_id is the canonical field that determines shop ownership
   - preferred_shop_id is just customer preference

2. ✅ Strict shop isolation enforced
   - ONLY mechanics in shop_mechanics table with matching shop_id can see request
   - Shop B mechanics will NOT see Shop A requests

3. ✅ Added shop_id to return columns
   - Helps with debugging and visibility

EXPECTED BEHAVIOR:
- Customer selects Shop A (shop_id = 'abc-123')
- Request created with shop_id = 'abc-123'
- Mechanic 1 (shop_mechanics.shop_id = 'abc-123') → ✅ Can see request
- Mechanic 2 (shop_mechanics.shop_id = 'xyz-789') → ❌ Cannot see request

DEPLOYMENT STEPS:
1. Run this SQL in Supabase SQL Editor
2. Restart Flutter app
3. Test with mechanics from different shops
4. Verify shop isolation is working
*/

SELECT '✅ Shop isolation fix complete!' as status;
SELECT '✅ Only mechanics from selected shop will see requests' as behavior;
