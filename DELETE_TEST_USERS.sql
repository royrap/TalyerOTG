-- ================================================================
-- DELETE TEST USERS AND ALL RELATED DATA
-- ================================================================
-- This script deletes three test users and cascades through all related tables
-- Users to delete:
-- 1. Riza Pineda (paengpineda471@gmail.com) - ID: 98543023-1960-4f70-b76a-d700ea70976c
-- 2. Mec Aid (mechanicroadaid@gmail.com) - ID: 19a8b4ca-f5f8-4b85-9147-5128d9651e04
-- 3. Yuji Fuma (yujirofuma28@gmail.com) - ID: e4cbf14b-5729-45ef-a124-1f2e05acad8c
-- ================================================================

BEGIN;

-- Store user IDs for easier reference
DO $$
DECLARE
    v_user1_id UUID := '98543023-1960-4f70-b76a-d700ea70976c'; -- Riza Pineda
    v_user2_id UUID := '19a8b4ca-f5f8-4b85-9147-5128d9651e04'; -- Mec Aid
    v_user3_id UUID := 'e4cbf14b-5729-45ef-a124-1f2e05acad8c'; -- Yuji Fuma
    v_shop1_id UUID := '5d963bdf-1879-4575-9375-df62b1ff3fe0'; -- Riza's shop
    v_shop2_id UUID := 'cedc2e63-7785-4d61-a8f1-9f4ed8d254da'; -- Mec Aid's shop
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Starting deletion of test users';
    RAISE NOTICE '========================================';

    -- ================================================================
    -- STEP 1: Delete from tables with direct user_id references
    -- ================================================================
    
    -- Account security logs
    DELETE FROM public.account_security_logs WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted account_security_logs';

    -- Admin activity logs
    DELETE FROM public.admin_activity_logs WHERE admin_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted admin_activity_logs';

    -- App downloads
    DELETE FROM public.app_downloads WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted app_downloads';

    -- Audit logs
    DELETE FROM public.audit_logs WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted audit_logs';

    -- Document verifications
    DELETE FROM public.document_verifications WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted document_verifications';

    -- Email notifications
    DELETE FROM public.email_notifications WHERE recipient_user_id IN (v_user1_id, v_user2_id, v_user3_id) 
        OR sender_user_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted email_notifications';

    -- Email verification tokens
    DELETE FROM public.email_verification_tokens WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted email_verification_tokens';

    -- Password reset tokens
    DELETE FROM public.password_reset_tokens WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted password_reset_tokens';

    -- Payment methods
    DELETE FROM public.payment_methods WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted payment_methods';

    -- Profile image logs
    DELETE FROM public.profile_image_logs WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted profile_image_logs';

    -- Profile updates
    DELETE FROM public.profile_updates WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id) 
        OR updated_by IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted profile_updates';

    -- User locations
    DELETE FROM public.user_locations WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted user_locations';

    -- User notification preferences
    DELETE FROM public.user_notification_preferences WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted user_notification_preferences';

    -- Do not disturb settings
    DELETE FROM public.do_not_disturb_settings WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted do_not_disturb_settings';

    -- Temporary passwords
    DELETE FROM public.temporary_passwords WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id) 
        OR created_by IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted temporary_passwords';

    -- ================================================================
    -- STEP 2: Delete service request related data
    -- ================================================================

    -- Cash payment verifications
    DELETE FROM public.cash_payment_verifications 
    WHERE customer_id IN (v_user1_id, v_user2_id, v_user3_id) 
        OR mechanic_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted cash_payment_verifications';

    -- Job completion codes
    DELETE FROM public.job_completion_codes WHERE customer_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted job_completion_codes';

    -- Service completions
    DELETE FROM public.service_completions 
    WHERE mechanic_id IN (v_user1_id, v_user2_id, v_user3_id) 
        OR customer_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted service_completions';

    -- Progress photos
    DELETE FROM public.progress_photos WHERE mechanic_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted progress_photos';

    -- Service phase tracking
    DELETE FROM public.service_phase_tracking WHERE mechanic_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted service_phase_tracking';

    -- Mechanic location tracking
    DELETE FROM public.mechanic_location_tracking 
    WHERE mechanic_id IN (v_user1_id, v_user2_id, v_user3_id) 
        OR customer_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted mechanic_location_tracking';

    -- Request status history
    DELETE FROM public.request_status_history WHERE changed_by IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted request_status_history';

    -- Messages
    DELETE FROM public.messages 
    WHERE sender_id IN (v_user1_id, v_user2_id, v_user3_id) 
        OR receiver_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted messages';

    -- Notifications
    DELETE FROM public.notifications WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted notifications';

    -- Request broadcasts
    DELETE FROM public.request_broadcasts WHERE mechanic_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted request_broadcasts';

    -- Request routing
    DELETE FROM public.request_routing WHERE eligible_mechanic_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted request_routing';

    -- Reviews
    DELETE FROM public.reviews WHERE customer_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted reviews';

    -- ================================================================
    -- STEP 3: Delete job history and service history
    -- ================================================================

    -- Customer job history
    DELETE FROM public.customer_job_history 
    WHERE customer_id IN (v_user1_id, v_user2_id, v_user3_id) 
        OR mechanic_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted customer_job_history';

    -- Mechanic job history
    DELETE FROM public.mechanic_job_history 
    WHERE mechanic_id IN (v_user1_id, v_user2_id, v_user3_id) 
        OR customer_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted mechanic_job_history';

    -- Service history
    DELETE FROM public.service_history 
    WHERE customer_id IN (v_user1_id, v_user2_id, v_user3_id) 
        OR talyer_owner_id IN (v_user1_id, v_user2_id, v_user3_id) 
        OR mechanic_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted service_history';

    -- ================================================================
    -- STEP 4: Delete payment and invoice data
    -- ================================================================

    -- Payment releases
    DELETE FROM public.payment_releases WHERE customer_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted payment_releases';

    -- Payments
    DELETE FROM public.payments WHERE customer_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted payments';

    -- Invoices
    DELETE FROM public.invoices 
    WHERE customer_id IN (v_user1_id, v_user2_id, v_user3_id) 
        OR talyer_owner_id IN (v_user1_id, v_user2_id, v_user3_id) 
        OR mechanic_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted invoices';

    -- ================================================================
    -- STEP 5: Delete service requests
    -- ================================================================

    DELETE FROM public.service_requests 
    WHERE customer_id IN (v_user1_id, v_user2_id, v_user3_id) 
        OR assigned_mechanic_id IN (v_user1_id, v_user2_id, v_user3_id)
        OR accepted_by IN (v_user1_id, v_user2_id, v_user3_id)
        OR rejected_by IN (v_user1_id, v_user2_id, v_user3_id)
        OR inspected_by IN (v_user1_id, v_user2_id, v_user3_id)
        OR qr_scanned_by IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted service_requests';

    -- Talyer customer connections
    DELETE FROM public.talyer_customer_connections 
    WHERE customer_id IN (v_user1_id, v_user2_id, v_user3_id) 
        OR talyer_owner_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted talyer_customer_connections';

    -- ================================================================
    -- STEP 6: Delete vehicles
    -- ================================================================

    DELETE FROM public.vehicles WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted vehicles';

    -- ================================================================
    -- STEP 7: Delete shop-related data
    -- ================================================================

    -- Shop notifications
    DELETE FROM public.shop_notifications 
    WHERE shop_owner_id IN (v_user1_id, v_user2_id, v_user3_id) 
        OR shop_id IN (v_shop1_id, v_shop2_id);
    RAISE NOTICE 'Deleted shop_notifications';

    -- Shop mechanics
    DELETE FROM public.shop_mechanics 
    WHERE mechanic_id IN (v_user1_id, v_user2_id, v_user3_id) 
        OR shop_id IN (v_shop1_id, v_shop2_id);
    RAISE NOTICE 'Deleted shop_mechanics';

    -- Service availability matrix
    DELETE FROM public.service_availability_matrix WHERE shop_id IN (v_shop1_id, v_shop2_id);
    RAISE NOTICE 'Deleted service_availability_matrix';

    -- Shop services
    DELETE FROM public.shop_services WHERE shop_id IN (v_shop1_id, v_shop2_id);
    RAISE NOTICE 'Deleted shop_services';

    -- Shop settings
    DELETE FROM public.shop_settings WHERE shop_id IN (v_shop1_id, v_shop2_id);
    RAISE NOTICE 'Deleted shop_settings';

    -- Shop stats cache
    DELETE FROM public.shop_stats_cache WHERE shop_id IN (v_shop1_id, v_shop2_id);
    RAISE NOTICE 'Deleted shop_stats_cache';

    -- Mechanic invitations
    DELETE FROM public.mechanic_invitations 
    WHERE shop_owner_id IN (v_user1_id, v_user2_id, v_user3_id) 
        OR mechanic_user_id IN (v_user1_id, v_user2_id, v_user3_id)
        OR shop_id IN (v_shop1_id, v_shop2_id);
    RAISE NOTICE 'Deleted mechanic_invitations';

    -- ================================================================
    -- STEP 8: Delete service provider data
    -- ================================================================

    -- Business permits
    DELETE FROM public.business_permits 
    WHERE provider_id IN (
        SELECT id FROM public.service_providers WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id)
    );
    RAISE NOTICE 'Deleted business_permits';

    -- Inspection reports
    DELETE FROM public.inspection_reports 
    WHERE provider_id IN (
        SELECT id FROM public.service_providers WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id)
    );
    RAISE NOTICE 'Deleted inspection_reports';

    -- Mechanic activity logs
    DELETE FROM public.mechanic_activity_logs 
    WHERE mechanic_id IN (
        SELECT id FROM public.service_providers WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id)
    );
    RAISE NOTICE 'Deleted mechanic_activity_logs';

    -- Provider services
    DELETE FROM public.provider_services 
    WHERE provider_id IN (
        SELECT id FROM public.service_providers WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id)
    );
    RAISE NOTICE 'Deleted provider_services';

    -- Provider availability cache
    DELETE FROM public.provider_availability_cache 
    WHERE provider_id IN (
        SELECT id FROM public.service_providers WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id)
    );
    RAISE NOTICE 'Deleted provider_availability_cache';

    -- Service providers
    DELETE FROM public.service_providers WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted service_providers';

    -- ================================================================
    -- STEP 9: Delete mechanic-specific data
    -- ================================================================

    -- Mechanic availability status
    DELETE FROM public.mechanic_availability_status WHERE mechanic_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted mechanic_availability_status';

    -- Mechanics
    DELETE FROM public.mechanics WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted mechanics';

    -- ================================================================
    -- STEP 10: Delete talyer owner verifications
    -- ================================================================

    DELETE FROM public.talyer_owner_verifications WHERE user_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted talyer_owner_verifications';

    -- ================================================================
    -- STEP 11: Delete shops (must be done before user_profiles)
    -- ================================================================

    DELETE FROM public.shops WHERE owner_id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted shops';

    -- ================================================================
    -- STEP 12: Delete user profiles
    -- ================================================================

    DELETE FROM public.user_profiles WHERE id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted user_profiles';

    -- ================================================================
    -- STEP 13: Delete from auth.users (final step)
    -- ================================================================

    DELETE FROM auth.users WHERE id IN (v_user1_id, v_user2_id, v_user3_id);
    RAISE NOTICE 'Deleted from auth.users';

    RAISE NOTICE '========================================';
    RAISE NOTICE 'Successfully deleted all test user data!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Users deleted:';
    RAISE NOTICE '  1. Riza Pineda (paengpineda471@gmail.com)';
    RAISE NOTICE '  2. Mec Aid (mechanicroadaid@gmail.com)';
    RAISE NOTICE '  3. Yuji Fuma (yujirofuma28@gmail.com)';
    RAISE NOTICE '========================================';

END $$;

COMMIT;

-- ================================================================
-- VERIFICATION QUERIES (Run these after the deletion)
-- ================================================================

-- Check if users are deleted
SELECT 'Remaining users check:' as check_type;
SELECT id, email, user_type FROM public.user_profiles 
WHERE id IN (
    '98543023-1960-4f70-b76a-d700ea70976c',
    '19a8b4ca-f5f8-4b85-9147-5128d9651e04',
    'e4cbf14b-5729-45ef-a124-1f2e05acad8c'
);

-- Check if auth.users are deleted
SELECT 'Remaining auth.users check:' as check_type;
SELECT id, email FROM auth.users 
WHERE id IN (
    '98543023-1960-4f70-b76a-d700ea70976c',
    '19a8b4ca-f5f8-4b85-9147-5128d9651e04',
    'e4cbf14b-5729-45ef-a124-1f2e05acad8c'
);

-- Check if shops are deleted
SELECT 'Remaining shops check:' as check_type;
SELECT id, shop_name, owner_id FROM public.shops 
WHERE id IN (
    '5d963bdf-1879-4575-9375-df62b1ff3fe0',
    'cedc2e63-7785-4d61-a8f1-9f4ed8d254da'
);
