-- ============================================================================
-- DELETE USER: Rafael Pined (rafaelpineda1128@gmail.com)
-- User ID: 55416e07-efb4-42c6-8cd3-87b1ee640d55
-- ============================================================================
-- This script safely deletes a user and all their related data from the database
-- Execute this in Supabase SQL Editor or your PostgreSQL client
-- ============================================================================

BEGIN;

-- Store user ID for reference
DO $$
DECLARE
    target_user_id UUID := '55416e07-efb4-42c6-8cd3-87b1ee640d55';
BEGIN
    RAISE NOTICE 'Starting deletion for user: %', target_user_id;
    RAISE NOTICE 'User: Rafael Pined (rafaelpineda1128@gmail.com)';
    RAISE NOTICE '============================================================';

    -- ========================================================================
    -- STEP 1: Delete from audit logs FIRST (has FK to user_profiles)
    -- ========================================================================
    RAISE NOTICE 'Step 1: Deleting audit logs...';
    
    -- CRITICAL: Delete audit_logs BEFORE user_profiles due to FK constraint
    DELETE FROM audit_logs WHERE user_id = target_user_id;
    RAISE NOTICE '  ✓ Deleted from audit_logs';

    -- ========================================================================
    -- STEP 2: Delete from notifications and messages
    -- ========================================================================
    RAISE NOTICE 'Step 2: Deleting notifications and messages...';
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'notifications') THEN
        DELETE FROM notifications WHERE user_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from notifications';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'push_notifications') THEN
        DELETE FROM push_notifications WHERE user_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from push_notifications';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'messages') THEN
        DELETE FROM messages WHERE sender_id = target_user_id OR receiver_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from messages';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'chat_messages') THEN
        DELETE FROM chat_messages WHERE sender_id = target_user_id OR receiver_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from chat_messages';
    END IF;

    -- ========================================================================
    -- STEP 3: Delete from service requests (as customer)
    -- ========================================================================
    RAISE NOTICE 'Step 3: Deleting service requests...';
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'service_request_images') THEN
        DELETE FROM service_request_images WHERE request_id IN (
            SELECT id FROM service_requests WHERE customer_id = target_user_id
        );
        RAISE NOTICE '  ✓ Deleted from service_request_images';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'service_request_history') THEN
        DELETE FROM service_request_history WHERE request_id IN (
            SELECT id FROM service_requests WHERE customer_id = target_user_id
        );
        RAISE NOTICE '  ✓ Deleted from service_request_history';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'service_requests') THEN
        DELETE FROM service_requests WHERE customer_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from service_requests (as customer)';
        
        DELETE FROM service_requests WHERE provider_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from service_requests (as provider)';
    END IF;

    -- ========================================================================
    -- STEP 4: Delete from payments and invoices
    -- ========================================================================
    RAISE NOTICE 'Step 4: Deleting payments and invoices...';
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'payment_failures') THEN
        DELETE FROM payment_failures WHERE invoice_id IN (
            SELECT id FROM invoices WHERE customer_id = target_user_id
        );
        RAISE NOTICE '  ✓ Deleted from payment_failures';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'paymongo_payment_intents') THEN
        DELETE FROM paymongo_payment_intents WHERE customer_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from paymongo_payment_intents';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'payments') THEN
        DELETE FROM payments WHERE customer_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from payments (as customer)';
        
        DELETE FROM payments WHERE provider_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from payments (as provider)';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'invoices') THEN
        DELETE FROM invoices WHERE customer_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from invoices';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'earnings') THEN
        DELETE FROM earnings WHERE provider_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from earnings';
    END IF;

    -- ========================================================================
    -- STEP 5: Delete from reviews and ratings
    -- ========================================================================
    RAISE NOTICE 'Step 5: Deleting reviews and ratings...';
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'reviews') THEN
        DELETE FROM reviews WHERE customer_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from reviews (as customer)';
        
        DELETE FROM reviews WHERE provider_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from reviews (as provider)';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'ratings') THEN
        DELETE FROM ratings WHERE customer_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from ratings (as customer)';
        
        DELETE FROM ratings WHERE provider_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from ratings (as provider)';
    END IF;

    -- ========================================================================
    -- STEP 6: Delete from vehicles
    -- ========================================================================
    RAISE NOTICE 'Step 6: Deleting vehicles...';
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'vehicle_images') THEN
        DELETE FROM vehicle_images WHERE vehicle_id IN (
            SELECT id FROM vehicles WHERE user_id = target_user_id
        );
        RAISE NOTICE '  ✓ Deleted from vehicle_images';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'vehicles') THEN
        DELETE FROM vehicles WHERE user_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from vehicles';
    END IF;

    -- ========================================================================
    -- STEP 7: Delete from locations and tracking
    -- ========================================================================
    RAISE NOTICE 'Step 7: Deleting location data...';
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'user_locations') THEN
        DELETE FROM user_locations WHERE user_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from user_locations';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'provider_locations') THEN
        DELETE FROM provider_locations WHERE provider_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from provider_locations';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'mechanic_locations') THEN
        DELETE FROM mechanic_locations WHERE mechanic_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from mechanic_locations';
    END IF;

    -- ========================================================================
    -- STEP 8: Delete from shop-related tables (if shop owner or mechanic)
    -- ========================================================================
    RAISE NOTICE 'Step 8: Deleting shop-related data...';
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'shop_mechanics') THEN
        DELETE FROM shop_mechanics WHERE mechanic_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from shop_mechanics';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'shop_services') THEN
        DELETE FROM shop_services WHERE shop_id IN (
            SELECT id FROM shops WHERE owner_id = target_user_id
        );
        RAISE NOTICE '  ✓ Deleted from shop_services';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'shop_images') THEN
        DELETE FROM shop_images WHERE shop_id IN (
            SELECT id FROM shops WHERE owner_id = target_user_id
        );
        RAISE NOTICE '  ✓ Deleted from shop_images';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'shop_schedules') THEN
        DELETE FROM shop_schedules WHERE shop_id IN (
            SELECT id FROM shops WHERE owner_id = target_user_id
        );
        RAISE NOTICE '  ✓ Deleted from shop_schedules';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'shops') THEN
        DELETE FROM shops WHERE owner_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from shops';
    END IF;

    -- ========================================================================
    -- STEP 9: Delete from service provider tables
    -- ========================================================================
    RAISE NOTICE 'Step 9: Deleting service provider data...';
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'service_provider_services') THEN
        DELETE FROM service_provider_services WHERE provider_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from service_provider_services';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'service_provider_availability') THEN
        DELETE FROM service_provider_availability WHERE provider_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from service_provider_availability';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'provider_documents') THEN
        DELETE FROM provider_documents WHERE provider_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from provider_documents';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'service_providers') THEN
        DELETE FROM service_providers WHERE user_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from service_providers';
    END IF;

    -- ========================================================================
    -- STEP 10: Delete from favorites and preferences
    -- ========================================================================
    RAISE NOTICE 'Step 10: Deleting favorites and preferences...';
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'favorite_providers') THEN
        DELETE FROM favorite_providers WHERE customer_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from favorite_providers';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'user_preferences') THEN
        DELETE FROM user_preferences WHERE user_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from user_preferences';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'user_settings') THEN
        DELETE FROM user_settings WHERE user_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from user_settings';
    END IF;

    -- ========================================================================
    -- STEP 11: Delete from sessions and tokens
    -- ========================================================================
    RAISE NOTICE 'Step 11: Deleting sessions and tokens...';
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'user_sessions') THEN
        DELETE FROM user_sessions WHERE user_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from user_sessions';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'fcm_tokens') THEN
        DELETE FROM fcm_tokens WHERE user_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from fcm_tokens';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'device_tokens') THEN
        DELETE FROM device_tokens WHERE user_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from device_tokens';
    END IF;

    -- ========================================================================
    -- STEP 12: Delete from verification and documents
    -- ========================================================================
    RAISE NOTICE 'Step 12: Deleting verification documents...';
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'verification_documents') THEN
        DELETE FROM verification_documents WHERE user_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from verification_documents';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'document_uploads') THEN
        DELETE FROM document_uploads WHERE user_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from document_uploads';
    END IF;

    -- ========================================================================
    -- STEP 13: Delete from broadcast requests
    -- ========================================================================
    RAISE NOTICE 'Step 13: Deleting broadcast requests...';
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'broadcast_request_responses') THEN
        DELETE FROM broadcast_request_responses WHERE request_id IN (
            SELECT id FROM broadcast_requests WHERE customer_id = target_user_id
        );
        RAISE NOTICE '  ✓ Deleted from broadcast_request_responses';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'broadcast_requests') THEN
        DELETE FROM broadcast_requests WHERE customer_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from broadcast_requests';
    END IF;

    -- ========================================================================
    -- STEP 14: Delete from job history
    -- ========================================================================
    RAISE NOTICE 'Step 14: Deleting job history...';
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'job_history') THEN
        DELETE FROM job_history WHERE mechanic_id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from job_history';
    END IF;

    -- ========================================================================
    -- STEP 15: Delete from user_profiles
    -- ========================================================================
    RAISE NOTICE 'Step 15: Deleting user profile...';
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'user_profiles') THEN
        DELETE FROM user_profiles WHERE id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from user_profiles';
    END IF;

    -- ========================================================================
    -- STEP 16: Delete from auth.users (Supabase Auth table)
    -- ========================================================================
    RAISE NOTICE 'Step 16: Deleting from auth.users...';
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'users') THEN
        DELETE FROM auth.users WHERE id = target_user_id;
        RAISE NOTICE '  ✓ Deleted from auth.users';
    END IF;

    -- ========================================================================
    RAISE NOTICE '============================================================';
    RAISE NOTICE '✅ User deletion completed successfully!';
    RAISE NOTICE 'User ID: %', target_user_id;
    RAISE NOTICE 'User: Rafael Pined (rafaelpineda1128@gmail.com)';
    RAISE NOTICE '============================================================';
END $$;

COMMIT;

-- Verify deletion
SELECT 
    'User deletion verification' as check_type,
    COUNT(*) as remaining_records
FROM user_profiles 
WHERE id = '55416e07-efb4-42c6-8cd3-87b1ee640d55';

-- Should return 0 if successfully deleted
