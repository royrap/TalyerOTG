-- Comprehensive Test Script for QR Job Completion with History Recording
-- This script tests the complete flow: QR generation → QR scanning → job completion → history recording

-- Clear any existing test data (optional - uncomment if needed)
-- DELETE FROM job_completion_codes WHERE completion_code LIKE 'TEST-%';
-- DELETE FROM mechanic_job_history WHERE job_title LIKE 'Test Job%';
-- DELETE FROM customer_job_history WHERE job_title LIKE 'Test Job%';

-- Test Phase 1: Setup test data
DO $$
DECLARE
    test_customer_id UUID := 'b47ac10b-58cc-4372-a567-0e02b2c3d479';
    test_mechanic_id UUID := 'c47ac10b-58cc-4372-a567-0e02b2c3d480';
    test_shop_id UUID := 'd47ac10b-58cc-4372-a567-0e02b2c3d481';
    test_request_id UUID := 'e47ac10b-58cc-4372-a567-0e02b2c3d482';
    test_completion_code TEXT := 'TEST-' || EXTRACT(EPOCH FROM NOW())::BIGINT::TEXT;
    test_completion_code_id UUID;
BEGIN
    RAISE NOTICE 'Starting QR Job Completion Test...';
    
    -- Create test user profiles first (required for foreign key constraints)
    INSERT INTO user_profiles (
        id,
        first_name,
        last_name,
        email,
        phone_number,
        user_type,
        created_at,
        updated_at
    ) VALUES (
        test_customer_id,
        'Test',
        'Customer',
        'test.customer@example.com',
        '+639123456789',
        'customer',
        NOW(),
        NOW()
    ) ON CONFLICT (id) DO UPDATE SET
        updated_at = NOW();
    
    INSERT INTO user_profiles (
        id,
        first_name,
        last_name,
        email,
        phone_number,
        user_type,
        created_at,
        updated_at
    ) VALUES (
        test_mechanic_id,
        'Test',
        'Mechanic',
        'test.mechanic@example.com',
        '+639987654321',
        'mechanic',
        NOW(),
        NOW()
    ) ON CONFLICT (id) DO UPDATE SET
        updated_at = NOW();
    
    -- Create test shop if not exists
    INSERT INTO shops (
        id,
        owner_id,
        shop_name,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        test_shop_id,
        test_mechanic_id,  -- Use mechanic as shop owner for simplicity
        'Test Auto Shop',
        true,
        NOW(),
        NOW()
    ) ON CONFLICT (id) DO UPDATE SET
        updated_at = NOW();
    
    -- Create test service request if not exists
    INSERT INTO service_requests (
        id,
        customer_id,
        assigned_mechanic_id,
        shop_id,
        title,
        description,
        status,
        pickup_latitude,
        pickup_longitude,
        pickup_address,
        final_price,
        service_type,
        created_at,
        updated_at
    ) VALUES (
        test_request_id,
        test_customer_id,
        test_mechanic_id,
        test_shop_id,
        'Test Job for QR Completion',
        'This is a test job to validate QR completion flow',
        'in_progress',
        14.5995,  -- Manila latitude
        120.9842, -- Manila longitude
        'Test Location, Manila, Philippines',
        1500.00,
        'Engine Repair',
        NOW(),
        NOW()
    ) ON CONFLICT (id) DO UPDATE SET
        status = 'in_progress',
        pickup_latitude = 14.5995,
        pickup_longitude = 120.9842,
        updated_at = NOW();
    
    -- Create test job completion code
    INSERT INTO job_completion_codes (
        request_id,
        customer_id,
        completion_code,
        is_used,
        created_at,
        expires_at,
        verification_status
    ) VALUES (
        test_request_id,
        test_customer_id,
        test_completion_code,
        FALSE,
        NOW(),
        NOW() + INTERVAL '24 hours',
        'pending'
    ) RETURNING id INTO test_completion_code_id;
    
    RAISE NOTICE 'Test data created:';
    RAISE NOTICE '- Request ID: %', test_request_id;
    RAISE NOTICE '- Customer ID: %', test_customer_id;
    RAISE NOTICE '- Mechanic ID: %', test_mechanic_id;
    RAISE NOTICE '- Shop ID: %', test_shop_id;
    RAISE NOTICE '- Completion Code: %', test_completion_code;
    RAISE NOTICE '- Completion Code ID: %', test_completion_code_id;
    
    -- Test Phase 2: Execute the QR completion function
    RAISE NOTICE 'Testing complete_job_with_qr_scan function...';
    
    IF complete_job_with_qr_scan(
        test_completion_code_id,
        test_request_id,
        test_mechanic_id,
        NOW(),
        14.5995,  -- Sample latitude (Manila)
        120.9842  -- Sample longitude (Manila)
    ) THEN
        RAISE NOTICE '✅ QR completion function executed successfully!';
    ELSE
        RAISE EXCEPTION '❌ QR completion function failed!';
    END IF;
    
END $$;

-- Test Phase 3: Validate results
SELECT 
    '=== SERVICE REQUEST STATUS ===' as test_section,
    sr.id,
    sr.status,
    sr.completed_at,
    sr.qr_scanned_at,
    sr.qr_scanned_by
FROM service_requests sr
WHERE sr.title LIKE 'Test Job%'
ORDER BY sr.created_at DESC
LIMIT 1;

SELECT 
    '=== JOB COMPLETION CODE STATUS ===' as test_section,
    jcc.completion_code,
    jcc.is_used,
    jcc.used_at,
    jcc.used_by_provider_id,
    jcc.verification_status,
    jcc.scan_latitude,
    jcc.scan_longitude
FROM job_completion_codes jcc
WHERE jcc.completion_code LIKE 'TEST-%'
ORDER BY jcc.created_at DESC
LIMIT 1;

SELECT 
    '=== MECHANIC JOB HISTORY ===' as test_section,
    mjh.id,
    mjh.mechanic_id,
    mjh.service_request_id,
    mjh.customer_id,
    mjh.shop_id,
    mjh.job_title,
    mjh.job_description,
    mjh.job_status,
    mjh.completed_at,
    mjh.total_amount,
    mjh.created_at
FROM mechanic_job_history mjh
WHERE mjh.job_title LIKE 'Test Job%'
ORDER BY mjh.created_at DESC
LIMIT 1;

SELECT 
    '=== CUSTOMER JOB HISTORY ===' as test_section,
    cjh.id,
    cjh.customer_id,
    cjh.service_request_id,
    cjh.mechanic_id,
    cjh.shop_id,
    cjh.job_title,
    cjh.job_description,
    cjh.job_status,
    cjh.completed_at,
    cjh.total_amount,
    cjh.mechanic_name,
    cjh.shop_name,
    cjh.created_at
FROM customer_job_history cjh
WHERE cjh.job_title LIKE 'Test Job%'
ORDER BY cjh.created_at DESC
LIMIT 1;

-- Test Phase 4: Test cancelled job history recording
DO $$
DECLARE
    test_cancelled_request_id UUID := 'f47ac10b-58cc-4372-a567-0e02b2c3d483';
    test_customer_id UUID := 'b47ac10b-58cc-4372-a567-0e02b2c3d479';
    test_mechanic_id UUID := 'c47ac10b-58cc-4372-a567-0e02b2c3d480';
    test_shop_id UUID := 'd47ac10b-58cc-4372-a567-0e02b2c3d481';
BEGIN
    RAISE NOTICE 'Testing cancelled job history recording...';
    
    -- User profiles and shop should already exist from Phase 1
    
    -- Create test cancelled service request
    INSERT INTO service_requests (
        id,
        customer_id,
        assigned_mechanic_id,
        shop_id,
        title,
        description,
        status,
        pickup_latitude,
        pickup_longitude,
        pickup_address,
        final_price,
        service_type,
        created_at,
        updated_at
    ) VALUES (
        test_cancelled_request_id,
        test_customer_id,
        test_mechanic_id,
        test_shop_id,
        'Test Job for Cancellation',
        'This is a test job to validate cancellation history',
        'in_progress',
        14.6042,  -- Quezon City latitude
        121.0222, -- Quezon City longitude
        'Test Cancellation Location, Quezon City, Philippines',
        800.00,
        'Brake Service',
        NOW(),
        NOW()
    ) ON CONFLICT (id) DO UPDATE SET
        status = 'in_progress',
        pickup_latitude = 14.6042,
        pickup_longitude = 121.0222,
        updated_at = NOW();
    
    -- Update to cancelled status (should trigger history recording)
    UPDATE service_requests 
    SET 
        status = 'cancelled',
        cancelled_at = NOW(),
        updated_at = NOW()
    WHERE id = test_cancelled_request_id;
    
    RAISE NOTICE '✅ Cancelled job test completed!';
END $$;

-- Validate cancelled job history
SELECT 
    '=== CANCELLED MECHANIC JOB HISTORY ===' as test_section,
    mjh.id,
    mjh.mechanic_id,
    mjh.service_request_id,
    mjh.job_title,
    mjh.job_status,
    mjh.cancelled_at,
    mjh.total_amount
FROM mechanic_job_history mjh
WHERE mjh.job_title LIKE 'Test Job for Cancellation%'
ORDER BY mjh.created_at DESC
LIMIT 1;

SELECT 
    '=== CANCELLED CUSTOMER JOB HISTORY ===' as test_section,
    cjh.id,
    cjh.customer_id,
    cjh.service_request_id,
    cjh.job_title,
    cjh.job_status,
    cjh.cancelled_at,
    cjh.total_amount
FROM customer_job_history cjh
WHERE cjh.job_title LIKE 'Test Job for Cancellation%'
ORDER BY cjh.created_at DESC
LIMIT 1;

-- Test Phase 5: Validate unique constraints work correctly
DO $$
DECLARE
    test_request_id UUID := 'e47ac10b-58cc-4372-a567-0e02b2c3d482';
    duplicate_count INT;
BEGIN
    RAISE NOTICE 'Testing duplicate history prevention...';
    
    -- Try to insert duplicate mechanic history (should be prevented by unique constraint)
    BEGIN
        INSERT INTO mechanic_job_history (
            mechanic_id,
            service_request_id,
            customer_id,
            job_title,
            job_status,
            completed_at,
            created_at,
            updated_at
        ) VALUES (
            'c47ac10b-58cc-4372-a567-0e02b2c3d480',
            test_request_id,
            'b47ac10b-58cc-4372-a567-0e02b2c3d479',
            'Duplicate Test Job',
            'completed',
            NOW(),
            NOW(),
            NOW()
        );
        RAISE EXCEPTION 'Expected unique constraint violation but insert succeeded';
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE '✅ Unique constraint working correctly for mechanic history';
    END;
    
    -- Check that we only have one record per mechanic-request pair
    SELECT COUNT(*) INTO duplicate_count
    FROM mechanic_job_history
    WHERE service_request_id = test_request_id;
    
    IF duplicate_count = 1 THEN
        RAISE NOTICE '✅ No duplicate mechanic history records found';
    ELSE
        RAISE NOTICE '⚠️  Found % mechanic history records (expected 1)', duplicate_count;
    END IF;
    
END $$;

-- Final Summary
SELECT 
    '=== TEST SUMMARY ===' as summary,
    (SELECT COUNT(*) FROM service_requests WHERE status = 'completed' AND title LIKE 'Test Job%') as completed_jobs,
    (SELECT COUNT(*) FROM job_completion_codes WHERE is_used = TRUE AND completion_code LIKE 'TEST-%') as used_qr_codes,
    (SELECT COUNT(*) FROM mechanic_job_history WHERE job_title LIKE 'Test Job%') as mechanic_history_entries,
    (SELECT COUNT(*) FROM customer_job_history WHERE job_title LIKE 'Test Job%') as customer_history_entries;

-- Cleanup (uncomment to remove test data)
-- DELETE FROM mechanic_job_history WHERE job_title LIKE 'Test Job%';
-- DELETE FROM customer_job_history WHERE job_title LIKE 'Test Job%';
-- DELETE FROM job_completion_codes WHERE completion_code LIKE 'TEST-%';
-- DELETE FROM service_requests WHERE title LIKE 'Test Job%';
-- DELETE FROM shops WHERE shop_name = 'Test Auto Shop';
-- DELETE FROM user_profiles WHERE email LIKE 'test.%@example.com';

-- Instructions for manual testing:
/*
MANUAL TESTING INSTRUCTIONS:

1. Run this test script to validate the database functions work correctly
2. In the Flutter app:
   - Create a service request and assign it to a mechanic
   - Generate an invoice and mark it as paid
   - Open the mechanic bottom sheet
   - Click the QR scanner button (should open camera)
   - Generate a QR code from the customer side
   - Scan the QR code with the mechanic app
   - Verify that:
     a) Job status changes to "completed"
     b) Job appears in mechanic job history
     c) Job appears in customer job history  
     d) Bottom sheet closes automatically
     e) Success messages are shown

3. Test cancellation flow:
   - Create another service request
   - Cancel it from either customer or mechanic side
   - Verify it appears in both job history tables with "cancelled" status

4. Check for edge cases:
   - Expired QR codes
   - Invalid QR codes
   - Duplicate scanning attempts
   - Network connectivity issues during scanning
*/

-- This comprehensive test script validates QR job completion with automatic history recording