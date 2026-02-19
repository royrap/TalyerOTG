-- ========================================
-- 🔍 CHECK MECHANIC DATA STRUCTURE
-- ========================================
-- This will show you EXACTLY what data exists
-- for mechanics in your shop
-- ========================================

SELECT 
  '=== 🔧 YOUR SHOP MECHANICS ===' as section;

-- Show shop mechanics with full user profile data
SELECT 
  sm.id as shop_mechanic_record_id,
  sm.mechanic_id,
  sm.shop_id,
  sm.is_active,
  sm.is_available,
  -- Mechanic user profile data
  up.first_name,
  up.last_name,
  up.email,
  up.phone_number,
  up.user_type,
  up.profile_image_url,
  up.rating,
  -- Shop data
  s.shop_name
FROM shop_mechanics sm
INNER JOIN user_profiles up ON up.id = sm.mechanic_id
INNER JOIN shops s ON s.id = sm.shop_id
WHERE sm.is_active = true
ORDER BY sm.joined_at DESC;

SELECT 
  '=== 📊 COMPLETED JOBS WITH MECHANIC NAMES ===' as section;

-- Show completed jobs with mechanic names
SELECT 
  sr.id as request_id,
  sr.status,
  sr.completed_at,
  sr.final_price,
  sr.mechanic_earnings,
  sr.shop_earnings,
  sr.platform_fee,
  -- Assigned mechanic details
  sr.assigned_mechanic_id,
  mech.first_name as mechanic_first_name,
  mech.last_name as mechanic_last_name,
  mech.email as mechanic_email,
  mech.user_type as mechanic_user_type,
  -- Shop details
  s.shop_name
FROM service_requests sr
LEFT JOIN user_profiles mech ON mech.id = sr.assigned_mechanic_id
LEFT JOIN shops s ON s.id = sr.shop_id
WHERE sr.status = 'completed'
ORDER BY sr.completed_at DESC;

SELECT 
  '=== 📜 MECHANIC JOB HISTORY WITH NAMES ===' as section;

-- Show job history with mechanic names
SELECT 
  mjh.id,
  mjh.job_title,
  mjh.job_status,
  mjh.completed_at,
  mjh.total_amount,
  mjh.mechanic_earnings,
  mjh.shop_earnings,
  mjh.platform_fee,
  -- Mechanic details
  mjh.mechanic_id,
  up.first_name,
  up.last_name,
  up.email,
  up.user_type,
  -- Shop details
  s.shop_name
FROM mechanic_job_history mjh
LEFT JOIN user_profiles up ON up.id = mjh.mechanic_id
LEFT JOIN shops s ON s.id = mjh.shop_id
WHERE mjh.job_status = 'completed'
ORDER BY mjh.completed_at DESC;

-- ========================================
-- SUMMARY
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ MECHANIC DATA STRUCTURE CHECK COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Look at the results above:';
    RAISE NOTICE '1. YOUR SHOP MECHANICS - Shows all mechanics with first_name/last_name';
    RAISE NOTICE '2. COMPLETED JOBS - Shows if mechanic_first_name and mechanic_last_name are populated';
    RAISE NOTICE '3. JOB HISTORY - Shows mechanic names from history table';
    RAISE NOTICE '';
    RAISE NOTICE 'If you see NULL in mechanic_first_name/mechanic_last_name:';
    RAISE NOTICE '  → The job has NO assigned_mechanic_id';
    RAISE NOTICE '  → OR the mechanic user_profile has NULL first_name/last_name';
    RAISE NOTICE '';
    RAISE NOTICE 'Copy the results and send to me so I can fix the Flutter code!';
    RAISE NOTICE '========================================';
END $$;
