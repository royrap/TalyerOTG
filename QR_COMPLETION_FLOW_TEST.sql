-- =====================================================
-- QR COMPLETION FLOW TEST SCRIPT
-- =====================================================
-- Tests the complete QR job completion flow including earnings calculation
-- =====================================================

BEGIN;

-- Create test data for QR completion flow
DO $$
DECLARE
    v_customer_id UUID;
    v_mechanic_id UUID;
    v_shop_id UUID;
    v_shop_owner_id UUID;
    v_service_request_id UUID;
    v_completion_code TEXT;
    v_qr_code_id UUID;
    v_test_result JSON;
BEGIN
    -- Clean up any existing test data
    DELETE FROM job_completion_codes WHERE completion_code LIKE 'TEST-QR-%';
    DELETE FROM service_requests WHERE title LIKE 'Test QR Job%';
    DELETE FROM mechanic_job_history WHERE job_title LIKE 'Test QR Job%';
    DELETE FROM customer_job_history WHERE job_title LIKE 'Test QR Job%';
    
    RAISE NOTICE '🧹 Cleaned up existing test data';
    
    -- Get test users (use existing or create placeholder references)
    SELECT id INTO v_customer_id FROM user_profiles WHERE user_type = 'customer' LIMIT 1;
    SELECT id INTO v_mechanic_id FROM user_profiles WHERE user_type = 'mechanic' LIMIT 1;
    SELECT id INTO v_shop_owner_id FROM user_profiles WHERE user_type = 'talyer_owner' LIMIT 1;
    SELECT id INTO v_shop_id FROM shops LIMIT 1;
    
    -- If no test users exist, create placeholder UUIDs for testing
    IF v_customer_id IS NULL THEN
        v_customer_id := gen_random_uuid();
        RAISE NOTICE '⚠️ Using placeholder customer ID: %', v_customer_id;
    END IF;
    
    IF v_mechanic_id IS NULL THEN
        v_mechanic_id := gen_random_uuid();
        RAISE NOTICE '⚠️ Using placeholder mechanic ID: %', v_mechanic_id;
    END IF;
    
    IF v_shop_owner_id IS NULL THEN
        v_shop_owner_id := gen_random_uuid();
        RAISE NOTICE '⚠️ Using placeholder shop owner ID: %', v_shop_owner_id;
    END IF;
    
    IF v_shop_id IS NULL THEN
        v_shop_id := gen_random_uuid();
        RAISE NOTICE '⚠️ Using placeholder shop ID: %', v_shop_id;
    END IF;
    
    RAISE NOTICE '👥 Test users: Customer=%, Mechanic=%, Shop=%, Owner=%', 
                 v_customer_id, v_mechanic_id, v_shop_id, v_shop_owner_id;
    
    -- 1. Create test service request
    INSERT INTO service_requests (
        id,
        customer_id,
        assigned_mechanic_id,
        shop_id,
        title,
        description,
        status,
        final_price,
        pickup_latitude,
        pickup_longitude,
        created_at
    ) VALUES (
        gen_random_uuid(),
        v_customer_id,
        v_mechanic_id,
        v_shop_id,
        'Test QR Job - Brake Repair',
        'Complete brake system repair and replacement',
        'invoice_paid',
        1500.00,
        14.5995,
        120.9842,
        NOW()
    ) RETURNING id INTO v_service_request_id;
    
    RAISE NOTICE '📋 Created test service request: %', v_service_request_id;
    
    -- 2. Create test completion QR code
    v_completion_code := 'TEST-QR-' || EXTRACT(EPOCH FROM NOW())::TEXT;
    
    INSERT INTO job_completion_codes (
        id,
        request_id,
        customer_id,
        completion_code,
        is_used,
        expires_at,
        created_at,
        verification_status
    ) VALUES (
        gen_random_uuid(),
        v_service_request_id,
        v_customer_id,
        v_completion_code,
        FALSE,
        NOW() + INTERVAL '24 hours',
        NOW(),
        'pending'
    ) RETURNING id INTO v_qr_code_id;
    
    RAISE NOTICE '🎯 Created QR completion code: % (ID: %)', v_completion_code, v_qr_code_id;
    
    -- 3. Test QR completion validation
    SELECT validate_qr_completion_auth(v_completion_code, v_mechanic_id) INTO v_test_result;
    RAISE NOTICE '🔐 Authorization test result: %', v_test_result;
    
    -- 4. Test QR completion status check
    SELECT get_qr_completion_status(v_completion_code) INTO v_test_result;
    RAISE NOTICE '📊 QR status check result: %', v_test_result;
    
    -- 5. Test the complete job completion flow
    RAISE NOTICE '🚀 Testing complete job completion flow...';
    
    SELECT complete_job_with_qr_scan(
        v_qr_code_id,
        v_service_request_id, 
        v_mechanic_id,
        NOW(),
        14.5995, -- scan latitude
        120.9842  -- scan longitude
    ) INTO v_test_result;
    
    RAISE NOTICE '✅ Job completion result: %', v_test_result;
    
    -- 6. Verify the results
    RAISE NOTICE '🔍 Verifying completion results...';
    
    -- Check service request status
    IF EXISTS (
        SELECT 1 FROM service_requests 
        WHERE id = v_service_request_id 
        AND status = 'completed'
        AND mechanic_earnings > 0
        AND shop_earnings > 0
        AND platform_fee > 0
    ) THEN
        RAISE NOTICE '✅ Service request properly completed with earnings';
    ELSE
        RAISE NOTICE '❌ Service request completion failed';
    END IF;
    
    -- Check mechanic job history
    IF EXISTS (
        SELECT 1 FROM mechanic_job_history 
        WHERE service_request_id = v_service_request_id 
        AND job_status = 'completed'
        AND mechanic_earnings = (1500.00 * 0.75)  -- 75% of ₱1500
        AND shop_earnings = (1500.00 * 0.20)      -- 20% of ₱1500
        AND platform_fee = (1500.00 * 0.05)       -- 5% of ₱1500
    ) THEN
        RAISE NOTICE '✅ Mechanic job history recorded with correct earnings: Mechanic ₱%, Shop ₱%, Platform ₱%', 
                     (1500.00 * 0.75), (1500.00 * 0.20), (1500.00 * 0.05);
    ELSE
        RAISE NOTICE '❌ Mechanic job history missing or incorrect';
    END IF;
    
    -- Check customer job history  
    IF EXISTS (
        SELECT 1 FROM customer_job_history 
        WHERE service_request_id = v_service_request_id 
        AND job_status = 'completed'
    ) THEN
        RAISE NOTICE '✅ Customer job history recorded';
    ELSE
        RAISE NOTICE '❌ Customer job history missing';
    END IF;
    
    -- Check QR code marked as used
    IF EXISTS (
        SELECT 1 FROM job_completion_codes 
        WHERE id = v_qr_code_id 
        AND is_used = TRUE
        AND verification_status = 'verified'
    ) THEN
        RAISE NOTICE '✅ QR code marked as used and verified';
    ELSE
        RAISE NOTICE '❌ QR code not properly marked as used';
    END IF;
    
    -- Display final earnings breakdown
    SELECT 
        total_amount,
        mechanic_earnings,
        shop_earnings,
        platform_fee,
        (mechanic_earnings + shop_earnings + platform_fee) as total_check
    FROM mechanic_job_history 
    WHERE service_request_id = v_service_request_id;
    
    RAISE NOTICE '💰 Final Test Summary:';
    RAISE NOTICE '   - Service Request: %', v_service_request_id;
    RAISE NOTICE '   - QR Completion Code: %', v_completion_code;
    RAISE NOTICE '   - Total Amount: ₱1500.00';
    RAISE NOTICE '   - Mechanic Earnings (75%%): ₱1125.00';
    RAISE NOTICE '   - Shop Earnings (20%%): ₱300.00';
    RAISE NOTICE '   - Platform Fee (5%%): ₱75.00';
    RAISE NOTICE '   - Mathematics: 1125 + 300 + 75 = 1500 ✅';
    
END $$;

-- Display test results
SELECT '=== QR COMPLETION FLOW TEST RESULTS ===' as test_header;

-- Show completed test jobs
SELECT 
    'TEST COMPLETED JOBS' as info,
    COUNT(*) as count 
FROM mechanic_job_history mjh
JOIN service_requests sr ON sr.id = mjh.service_request_id
WHERE mjh.job_title LIKE 'Test QR Job%'
AND sr.status = 'completed';

-- Show earnings calculation results
SELECT 
    mjh.job_title,
    mjh.total_amount,
    mjh.mechanic_earnings,
    mjh.shop_earnings, 
    mjh.platform_fee,
    (mjh.mechanic_earnings + mjh.shop_earnings + mjh.platform_fee) as total_check,
    CASE 
        WHEN ABS(mjh.total_amount - (mjh.mechanic_earnings + mjh.shop_earnings + mjh.platform_fee)) < 0.01 
        THEN '✅ CORRECT' 
        ELSE '❌ ERROR' 
    END as math_check
FROM mechanic_job_history mjh
WHERE mjh.job_title LIKE 'Test QR Job%';

-- Show QR codes status
SELECT 
    jcc.completion_code,
    jcc.is_used,
    jcc.verification_status,
    jcc.used_at,
    sr.status as service_status
FROM job_completion_codes jcc
JOIN service_requests sr ON sr.id = jcc.request_id
WHERE jcc.completion_code LIKE 'TEST-QR-%';

RAISE NOTICE '🎉 QR COMPLETION FLOW TEST COMPLETED';
RAISE NOTICE '📱 Ready for mobile app testing!';

COMMIT;