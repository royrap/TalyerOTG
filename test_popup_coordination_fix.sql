-- Test script to validate the location-based popup coordination and customer payment flow
-- This script tests two critical fixes:
-- 1. Multi-mechanic popup hiding when someone accepts
-- 2. Customer payment navigation when mechanic accepts location-based request

-- Test 1: Multi-mechanic coordination
-- When one mechanic accepts, other mechanics should stop seeing the popup

-- Create test mechanics with availability
DO $$
DECLARE
    mechanic1_id UUID;
    mechanic2_id UUID;
    test_request_id UUID;
    customer_id UUID;
BEGIN
    -- Get or create test customer
    SELECT id INTO customer_id FROM auth.users WHERE email = 'test-customer@roadaid.com' LIMIT 1;
    IF customer_id IS NULL THEN
        RAISE NOTICE 'Please create a test customer first with email: test-customer@roadaid.com';
        RETURN;
    END IF;

    -- Get test mechanics
    SELECT id INTO mechanic1_id FROM auth.users WHERE email = 'mechanic1@roadaid.com' LIMIT 1;
    SELECT id INTO mechanic2_id FROM auth.users WHERE email = 'mechanic2@roadaid.com' LIMIT 1;
    
    IF mechanic1_id IS NULL OR mechanic2_id IS NULL THEN
        RAISE NOTICE 'Please create test mechanics: mechanic1@roadaid.com, mechanic2@roadaid.com';
        RETURN;
    END IF;

    -- Ensure both mechanics have availability status and are online
    INSERT INTO mechanic_availability_status (
        mechanic_id,
        is_accepting_requests,
        current_status,
        location_latitude,
        location_longitude,
        last_location_update,
        last_status_update
    ) VALUES 
    (mechanic1_id, true, 'available', 14.5995, 120.9842, NOW(), NOW()),
    (mechanic2_id, true, 'available', 14.6000, 120.9850, NOW(), NOW())
    ON CONFLICT (mechanic_id) DO UPDATE SET
        is_accepting_requests = true,
        current_status = 'available',
        location_latitude = EXCLUDED.location_latitude,
        location_longitude = EXCLUDED.location_longitude,
        last_location_update = NOW(),
        last_status_update = NOW();

    -- Create a test location-based service request
    INSERT INTO service_requests (
        customer_id,
        title,
        description,
        service_type,
        pickup_latitude,
        pickup_longitude,
        pickup_address,
        estimated_price,
        status,
        is_emergency,
        priority,
        created_at
    ) VALUES (
        customer_id,
        'TEST: Multi-mechanic Coordination',
        'Test request to validate popup hiding when someone accepts',
        'emergency_repair',
        14.5997, -- Very close to both mechanics
        120.9845,
        'Test Location, Manila',
        750.0,
        'pending',
        false,
        'normal',
        NOW()
    ) RETURNING id INTO test_request_id;

    RAISE NOTICE '🧪 TEST 1 SETUP COMPLETE:';
    RAISE NOTICE '📋 Test Request ID: %', test_request_id;
    RAISE NOTICE '🔧 Mechanic 1 ID: %', mechanic1_id;
    RAISE NOTICE '🔧 Mechanic 2 ID: %', mechanic2_id;
    RAISE NOTICE '👤 Customer ID: %', customer_id;
    RAISE NOTICE '';
    RAISE NOTICE '📱 MANUAL TEST STEPS:';
    RAISE NOTICE '1. Both mechanics should see popup automatically within 10 seconds';
    RAISE NOTICE '2. Mechanic 1 accepts the request';
    RAISE NOTICE '3. Mechanic 2''s popup should disappear immediately';
    RAISE NOTICE '4. Customer should see payment notification';
    RAISE NOTICE '';

END $$;

-- Test 2: Customer payment navigation verification
-- Check that customer notification service will trigger payment flow

RAISE NOTICE '🧪 TEST 2: Customer Payment Navigation Flow';
RAISE NOTICE '';
RAISE NOTICE '📊 Current customer notification service behavior:';
RAISE NOTICE '- Listens for status = ''awaiting_payment''';
RAISE NOTICE '- Shows payment dialog when mechanic accepts';
RAISE NOTICE '- Navigates to payment screen';
RAISE NOTICE '';

-- Show the current service requests that would trigger payment notifications
SELECT 
    sr.id,
    sr.title,
    sr.status,
    sr.assigned_mechanic_id,
    sr.created_at,
    up.first_name || ' ' || up.last_name as customer_name
FROM service_requests sr
LEFT JOIN user_profiles up ON sr.customer_id = up.id
WHERE sr.status = 'awaiting_payment'
AND sr.created_at > NOW() - INTERVAL '1 hour'
ORDER BY sr.created_at DESC;

RAISE NOTICE '';
RAISE NOTICE '✅ VALIDATION CHECKLIST:';
RAISE NOTICE '';
RAISE NOTICE '1. MULTI-MECHANIC COORDINATION:';
RAISE NOTICE '   □ Both mechanics see popup automatically';
RAISE NOTICE '   □ First mechanic accepts request';
RAISE NOTICE '   □ Other mechanics'' popups disappear immediately';
RAISE NOTICE '   □ Request status changes to "awaiting_payment"';
RAISE NOTICE '';
RAISE NOTICE '2. CUSTOMER PAYMENT FLOW:';
RAISE NOTICE '   □ Customer receives payment notification popup';
RAISE NOTICE '   □ Customer can navigate to payment screen';
RAISE NOTICE '   □ Payment screen shows correct mechanic details';
RAISE NOTICE '   □ Payment process works properly';
RAISE NOTICE '';
RAISE NOTICE '3. SYSTEM BEHAVIOR:';
RAISE NOTICE '   □ Real-time updates work correctly';
RAISE NOTICE '   □ No duplicate popups appear';
RAISE NOTICE '   □ Database consistency maintained';
RAISE NOTICE '   □ Proper error handling for edge cases';
RAISE NOTICE '';

-- Query to check the real-time subscription setup
RAISE NOTICE '📡 REAL-TIME CHANNELS THAT SHOULD BE ACTIVE:';
RAISE NOTICE '- request_routing (for shop-based requests)';
RAISE NOTICE '- service_requests_status (for hiding popups when accepted)';
RAISE NOTICE '- service_requests (customer payment notifications)';
RAISE NOTICE '';

-- Check current mechanic availability for testing
RAISE NOTICE '🔧 AVAILABLE MECHANICS FOR TESTING:';
SELECT 
    mas.mechanic_id,
    up.first_name || ' ' || up.last_name as mechanic_name,
    mas.is_accepting_requests,
    mas.current_status,
    mas.location_latitude,
    mas.location_longitude
FROM mechanic_availability_status mas
LEFT JOIN user_profiles up ON mas.mechanic_id = up.id
WHERE mas.is_accepting_requests = true
AND mas.current_status = 'available';

-- Sample coordinates for testing distance calculations
RAISE NOTICE '';
RAISE NOTICE '📍 TEST COORDINATES:';
RAISE NOTICE 'Manila Center: 14.5995, 120.9842';
RAISE NOTICE 'Nearby Point 1: 14.6000, 120.9850 (~0.6km away)';
RAISE NOTICE 'Nearby Point 2: 14.5990, 120.9835 (~0.8km away)';
RAISE NOTICE 'Far Point: 14.7000, 121.1000 (~25km away)';
RAISE NOTICE '';

RAISE NOTICE '🎯 EXPECTED BEHAVIOR SUMMARY:';
RAISE NOTICE '';
RAISE NOTICE 'BEFORE FIX:';
RAISE NOTICE '❌ Multiple mechanics see same popup indefinitely';
RAISE NOTICE '❌ Customer doesn''t get payment notification for location-based requests';
RAISE NOTICE '';
RAISE NOTICE 'AFTER FIX:';
RAISE NOTICE '✅ Popups auto-hide when someone else accepts';
RAISE NOTICE '✅ Customer gets payment notification for location-based requests';
RAISE NOTICE '✅ Real-time coordination between all mechanics';
RAISE NOTICE '✅ Proper status flow: pending → awaiting_payment → in_progress';
RAISE NOTICE '';

-- Test cleanup query (run this after testing)
/*
-- CLEANUP SCRIPT (uncomment to run after testing):
DELETE FROM service_requests 
WHERE title LIKE 'TEST:%' 
AND created_at > NOW() - INTERVAL '1 hour';

UPDATE mechanic_availability_status 
SET is_accepting_requests = false 
WHERE mechanic_id IN (
    SELECT id FROM auth.users 
    WHERE email LIKE '%@roadaid.com' 
    AND email LIKE 'mechanic%'
);

RAISE NOTICE 'Test data cleaned up';
*/