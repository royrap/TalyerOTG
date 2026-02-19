-- ========================================
-- 🔍 CHECK EXACT DASHBOARD QUERY DATA
-- ========================================
-- This simulates what the Flutter app queries
-- to see the exact data structure returned
-- ========================================

-- Check what getShopMechanics() returns
SELECT 
  '=== 📊 SHOP MECHANICS QUERY (Flutter getShopMechanics) ===' as section;

-- This is what the Flutter app queries
SELECT 
  sm.*,
  jsonb_build_object(
    'id', up.id,
    'first_name', up.first_name,
    'last_name', up.last_name,
    'email', up.email,
    'phone_number', up.phone_number,
    'profile_image_url', up.profile_image_url,
    'rating', up.rating,
    'total_reviews', up.total_reviews,
    'status', up.status,
    'is_available', up.is_available
  ) as mechanic
FROM shop_mechanics sm
INNER JOIN user_profiles up ON up.id = sm.mechanic_id
WHERE sm.is_active = true
ORDER BY sm.joined_at DESC;

-- Check what getMechanicsJobStats() uses
SELECT 
  '=== 📊 MECHANICS JOB STATS QUERY ===' as section;

-- Show mechanic job history with mechanic info
SELECT 
  mjh.id,
  mjh.job_title,
  mjh.job_status,
  mjh.total_amount,
  mjh.mechanic_earnings,
  mjh.shop_earnings,
  mjh.platform_fee,
  mjh.mechanic_id,
  -- This is what should be in the 'mechanic' field
  jsonb_build_object(
    'id', up.id,
    'first_name', up.first_name,
    'last_name', up.last_name,
    'email', up.email,
    'user_type', up.user_type
  ) as mechanic_object
FROM mechanic_job_history mjh
INNER JOIN user_profiles up ON up.id = mjh.mechanic_id
WHERE mjh.job_status = 'completed'
ORDER BY mjh.completed_at DESC;

-- Summary
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ DATA STRUCTURE CHECK COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Check the "mechanic" column above:';
    RAISE NOTICE '  - Should contain first_name: "yujiro"';
    RAISE NOTICE '  - Should contain last_name: "fuma"';
    RAISE NOTICE '';
    RAISE NOTICE 'If these are present, then the Flutter code fix will work!';
    RAISE NOTICE 'Hot reload the app and check the dashboard!';
    RAISE NOTICE '========================================';
END $$;
