-- DEBUG MECHANIC VISIBILITY ISSUE
-- This script helps identify why only rafaelpineda471 can see broadcast requests

-- =====================================================
-- STEP 1: CHECK ALL MECHANICS IN THE SYSTEM
-- =====================================================

-- Check all mechanics in mechanic_availability_status table
SELECT 
    'MECHANIC_AVAILABILITY_STATUS' as table_name,
    mas.mechanic_id,
    up.first_name,
    up.last_name,
    mas.current_status,
    mas.is_accepting_requests,
    mas.location_latitude,
    mas.location_longitude,
    mas.current_request_id,
    mas.last_status_update
FROM mechanic_availability_status mas
LEFT JOIN user_profiles up ON up.id = mas.mechanic_id
ORDER BY mas.last_status_update DESC;

-- =====================================================
-- STEP 2: CHECK WHO WOULD BE FOUND BY BROADCAST
-- =====================================================

-- Test the broadcast function query directly with sample coordinates
-- Using Manila coordinates as example: 14.5995, 120.9842
SELECT 
    'BROADCAST_ELIGIBILITY_TEST' as test_name,
    mas.mechanic_id,
    up.first_name,
    up.last_name,
    mas.current_status,
    mas.is_accepting_requests,
    mas.location_latitude,
    mas.location_longitude,
    mas.current_request_id,
    -- Calculate distance from Manila city center
    CASE 
        WHEN mas.location_latitude IS NOT NULL AND mas.location_longitude IS NOT NULL THEN
            (6371 * acos(
                cos(radians(14.5995)) * 
                cos(radians(mas.location_latitude)) * 
                cos(radians(mas.location_longitude) - radians(120.9842)) + 
                sin(radians(14.5995)) * 
                sin(radians(mas.location_latitude))
            ))
        ELSE NULL
    END as distance_km,
    -- Check all conditions
    CASE 
        WHEN mas.is_accepting_requests = true 
        AND mas.current_status = 'available'
        AND mas.location_latitude IS NOT NULL
        AND mas.location_longitude IS NOT NULL
        AND mas.current_request_id IS NULL
        THEN 'ELIGIBLE'
        ELSE 'NOT_ELIGIBLE'
    END as eligibility_status,
    -- Reason for ineligibility
    CASE 
        WHEN mas.is_accepting_requests != true THEN 'not_accepting_requests'
        WHEN mas.current_status != 'available' THEN 'status_not_available'
        WHEN mas.location_latitude IS NULL THEN 'no_latitude'
        WHEN mas.location_longitude IS NULL THEN 'no_longitude'
        WHEN mas.current_request_id IS NOT NULL THEN 'has_current_request'
        ELSE 'eligible'
    END as ineligibility_reason
FROM mechanic_availability_status mas
LEFT JOIN user_profiles up ON up.id = mas.mechanic_id
ORDER BY distance_km ASC NULLS LAST;

-- =====================================================
-- STEP 3: CHECK REQUEST ROUTING TABLE
-- =====================================================

-- Check recent request routing entries
SELECT 
    'RECENT_REQUEST_ROUTING' as table_name,
    rr.id as routing_id,
    rr.request_id,
    rr.eligible_mechanic_id,
    up.first_name,
    up.last_name,
    rr.distance_km,
    rr.routing_type,
    rr.is_notified,
    rr.created_at,
    sr.status as request_status,
    sr.assigned_mechanic_id
FROM request_routing rr
LEFT JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
LEFT JOIN service_requests sr ON sr.id = rr.request_id
ORDER BY rr.created_at DESC
LIMIT 20;

-- =====================================================
-- STEP 4: CHECK THE LATEST SERVICE REQUEST
-- =====================================================

-- Get the most recent service request details
SELECT 
    'LATEST_SERVICE_REQUEST' as table_name,
    sr.id,
    sr.title,
    sr.customer_id,
    sr.shop_id,
    sr.pickup_latitude,
    sr.pickup_longitude,
    sr.status,
    sr.assigned_mechanic_id,
    sr.request_type,
    sr.broadcast_radius_km,
    sr.mechanics_notified_count,
    sr.broadcast_timestamp,
    sr.created_at
FROM service_requests sr
ORDER BY sr.created_at DESC
LIMIT 5;

-- =====================================================
-- STEP 5: SIMULATE BROADCAST FOR LATEST REQUEST
-- =====================================================

-- Get the latest request and simulate broadcast
DO $$
DECLARE
    latest_request record;
    broadcast_result jsonb;
BEGIN
    -- Get the most recent request without assigned mechanic
    SELECT * INTO latest_request 
    FROM service_requests 
    WHERE assigned_mechanic_id IS NULL 
    AND status = 'pending'
    ORDER BY created_at DESC 
    LIMIT 1;
    
    IF latest_request.id IS NOT NULL THEN
        RAISE NOTICE 'Testing broadcast for request: %', latest_request.id;
        RAISE NOTICE 'Request location: %, %', latest_request.pickup_latitude, latest_request.pickup_longitude;
        
        -- Test broadcast function
        SELECT broadcast_service_request(
            latest_request.id::text,
            latest_request.pickup_latitude,
            latest_request.pickup_longitude,
            10.0
        ) INTO broadcast_result;
        
        RAISE NOTICE 'Broadcast test result: %', broadcast_result;
    ELSE
        RAISE NOTICE 'No pending requests found for testing';
    END IF;
END $$;

-- =====================================================
-- STEP 6: FIX MISSING MECHANIC DATA
-- =====================================================

-- Find users who might be mechanics but don't have availability status
SELECT 
    'MISSING_AVAILABILITY_STATUS' as issue_type,
    up.id,
    up.first_name,
    up.last_name,
    up.user_type,
    up.created_at
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic'
AND mas.mechanic_id IS NULL
ORDER BY up.created_at DESC;

-- Create missing mechanic_availability_status records
INSERT INTO mechanic_availability_status (
    mechanic_id,
    current_status,
    is_accepting_requests,
    last_status_update
)
SELECT 
    up.id,
    'available',
    true,
    NOW()
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic'
AND mas.mechanic_id IS NULL
ON CONFLICT (mechanic_id) DO NOTHING;

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '🔍 MECHANIC VISIBILITY DEBUG COMPLETE!';
    RAISE NOTICE '';
    RAISE NOTICE 'Check the results above to identify why other mechanics';
    RAISE NOTICE 'cannot see broadcast requests. Common issues:';
    RAISE NOTICE '1. Missing location coordinates (latitude/longitude)';
    RAISE NOTICE '2. is_accepting_requests = false';
    RAISE NOTICE '3. current_status != available';
    RAISE NOTICE '4. Missing mechanic_availability_status record';
    RAISE NOTICE '';
    RAISE NOTICE 'Any missing mechanic records have been automatically created.';
END $$;