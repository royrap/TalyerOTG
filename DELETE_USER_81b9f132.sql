-- =====================================================
-- DELETE USER: 81b9f132-1873-43cf-b1e4-e8cff7836e21
-- =====================================================
-- This script removes all records for this user from ALL tables
-- WARNING: This is a destructive operation. Make sure you have backups!

-- =====================================================
-- RUN THIS IN SUPABASE SQL EDITOR
-- =====================================================

BEGIN;

-- Get user info before deletion (for reference)
DO $$
DECLARE
    user_email TEXT;
    user_name TEXT;
    user_type_val TEXT;
BEGIN
    SELECT email, first_name || ' ' || last_name, user_type 
    INTO user_email, user_name, user_type_val
    FROM public.user_profiles 
    WHERE id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';
    
    IF user_email IS NOT NULL THEN
        RAISE NOTICE '🗑️  Deleting user: % (%) - Type: %', user_name, user_email, user_type_val;
    ELSE
        RAISE NOTICE '⚠️  User 81b9f132-1873-43cf-b1e4-e8cff7836e21 not found in user_profiles';
    END IF;
END $$;

-- =====================================================
-- DELETE FROM DEPENDENT TABLES FIRST (to avoid FK violations)
-- =====================================================

-- Delete from account_security_logs
DELETE FROM public.account_security_logs 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from admin_activity_logs
DELETE FROM public.admin_activity_logs 
WHERE admin_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from app_downloads
DELETE FROM public.app_downloads 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from audit_logs
DELETE FROM public.audit_logs 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from business_permits (if provider)
DELETE FROM public.business_permits 
WHERE provider_id IN (
    SELECT id FROM public.service_providers 
    WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
);

-- Delete from cash_payment_verifications
DELETE FROM public.cash_payment_verifications 
WHERE customer_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR mechanic_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR verified_by = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from customer_job_history
DELETE FROM public.customer_job_history 
WHERE customer_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR mechanic_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from do_not_disturb_settings
DELETE FROM public.do_not_disturb_settings 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from document_verifications
DELETE FROM public.document_verifications 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR verified_by = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from email_notifications
DELETE FROM public.email_notifications 
WHERE recipient_user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR sender_user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from email_verification_tokens
DELETE FROM public.email_verification_tokens 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from inspection_reports (if provider)
DELETE FROM public.inspection_reports 
WHERE provider_id IN (
    SELECT id FROM public.service_providers 
    WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
);

-- Delete from invoices
DELETE FROM public.invoices 
WHERE customer_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR talyer_owner_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR mechanic_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from job_completion_codes
DELETE FROM public.job_completion_codes 
WHERE customer_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from mechanic_activity_logs (if mechanic/provider)
DELETE FROM public.mechanic_activity_logs 
WHERE mechanic_id IN (
    SELECT id FROM public.service_providers 
    WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
);

-- Delete from mechanic_availability_status
DELETE FROM public.mechanic_availability_status 
WHERE mechanic_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from mechanic_invitations
DELETE FROM public.mechanic_invitations 
WHERE shop_owner_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR mechanic_user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from mechanic_job_history
DELETE FROM public.mechanic_job_history 
WHERE mechanic_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR customer_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from mechanic_location_tracking
DELETE FROM public.mechanic_location_tracking 
WHERE mechanic_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR customer_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from mechanics
DELETE FROM public.mechanics 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from messages
DELETE FROM public.messages 
WHERE sender_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR receiver_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from notifications
DELETE FROM public.notifications 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from password_reset_tokens
DELETE FROM public.password_reset_tokens 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from payment_methods
DELETE FROM public.payment_methods 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from payment_releases
DELETE FROM public.payment_releases 
WHERE customer_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR admin_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from payments
DELETE FROM public.payments 
WHERE customer_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from profile_image_logs
DELETE FROM public.profile_image_logs 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from profile_updates
DELETE FROM public.profile_updates 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR updated_by = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from progress_photos
DELETE FROM public.progress_photos 
WHERE mechanic_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from provider_availability_cache (if provider)
DELETE FROM public.provider_availability_cache 
WHERE provider_id IN (
    SELECT id FROM public.service_providers 
    WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
);

-- Delete from provider_services (if provider)
DELETE FROM public.provider_services 
WHERE provider_id IN (
    SELECT id FROM public.service_providers 
    WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
);

-- Delete from request_broadcasts
DELETE FROM public.request_broadcasts 
WHERE mechanic_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from request_routing
DELETE FROM public.request_routing 
WHERE eligible_mechanic_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from request_status_history
DELETE FROM public.request_status_history 
WHERE changed_by = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from reviews
DELETE FROM public.reviews 
WHERE customer_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from service_completions
DELETE FROM public.service_completions 
WHERE mechanic_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR customer_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from service_history
DELETE FROM public.service_history 
WHERE customer_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR talyer_owner_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR mechanic_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from service_phase_tracking
DELETE FROM public.service_phase_tracking 
WHERE mechanic_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from service_requests
DELETE FROM public.service_requests 
WHERE customer_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR assigned_mechanic_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR qr_scanned_by = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR accepted_by = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR rejected_by = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR inspected_by = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from shop_mechanics
DELETE FROM public.shop_mechanics 
WHERE mechanic_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from shop_notifications
DELETE FROM public.shop_notifications 
WHERE shop_owner_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from shop_stats_cache (if owns shop)
DELETE FROM public.shop_stats_cache 
WHERE shop_id IN (
    SELECT id FROM public.shops 
    WHERE owner_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
);

-- Delete from shop_services (if owns shop)
DELETE FROM public.shop_services 
WHERE shop_id IN (
    SELECT id FROM public.shops 
    WHERE owner_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
);

-- Delete from shop_settings (if owns shop)
DELETE FROM public.shop_settings 
WHERE shop_id IN (
    SELECT id FROM public.shops 
    WHERE owner_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
);

-- Delete from service_availability_matrix (if owns shop)
DELETE FROM public.service_availability_matrix 
WHERE shop_id IN (
    SELECT id FROM public.shops 
    WHERE owner_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
);

-- Delete from shops (if owns shop)
DELETE FROM public.shops 
WHERE owner_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from talyer_customer_connections
DELETE FROM public.talyer_customer_connections 
WHERE customer_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR talyer_owner_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from talyer_owner_verifications
DELETE FROM public.talyer_owner_verifications 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR reviewed_by = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from temporary_passwords
DELETE FROM public.temporary_passwords 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR created_by = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from user_locations
DELETE FROM public.user_locations 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from user_notification_preferences
DELETE FROM public.user_notification_preferences 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from vehicles
DELETE FROM public.vehicles 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from service_providers (if provider/mechanic)
DELETE FROM public.service_providers 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR talyer_owner_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- =====================================================
-- DELETE FROM MAIN TABLES
-- =====================================================

-- Delete from user_profiles
DELETE FROM public.user_profiles 
WHERE id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'
   OR verified_by = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- Delete from auth.users (FINAL STEP)
DELETE FROM auth.users 
WHERE id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Deletion complete!';
    RAISE NOTICE '🔍 Verifying user is gone from all tables...';
END $$;

-- Check if user still exists anywhere
SELECT 
    'user_profiles' as table_name,
    COUNT(*) as remaining_records
FROM public.user_profiles 
WHERE id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'

UNION ALL

SELECT 
    'auth.users' as table_name,
    COUNT(*) as remaining_records
FROM auth.users 
WHERE id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'

UNION ALL

SELECT 
    'service_providers' as table_name,
    COUNT(*) as remaining_records
FROM public.service_providers 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21'

UNION ALL

SELECT 
    'vehicles' as table_name,
    COUNT(*) as remaining_records
FROM public.vehicles 
WHERE user_id = '81b9f132-1873-43cf-b1e4-e8cff7836e21';

COMMIT;

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '✅✅✅ User 81b9f132-1873-43cf-b1e4-e8cff7836e21 has been completely deleted!';
    RAISE NOTICE '📊 Check the verification results above to confirm (all counts should be 0)';
END $$;
