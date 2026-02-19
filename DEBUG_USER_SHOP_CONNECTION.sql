-- ========================================
-- DEBUG: Check Current User and Shop Connection
-- ========================================

-- Check who is currently logged in
SELECT 
  '=== 🔍 CURRENT USER INFO ===' as section;

SELECT 
  auth.uid() as current_auth_uid,
  (SELECT email FROM auth.users WHERE id = auth.uid()) as current_email,
  (SELECT first_name || ' ' || last_name FROM user_profiles WHERE id = auth.uid()) as current_name,
  (SELECT user_type FROM user_profiles WHERE id = auth.uid()) as user_type;

-- Check if user has a shop
SELECT 
  '=== 🏪 SHOP LOOKUP ===' as section;

SELECT 
  s.id as shop_id,
  s.shop_name,
  s.owner_id,
  up.first_name || ' ' || up.last_name as owner_name,
  up.email as owner_email
FROM shops s
LEFT JOIN user_profiles up ON up.id = s.owner_id
WHERE s.owner_id = auth.uid();

-- If no results, check all shops
SELECT 
  '=== 📋 ALL SHOPS (for reference) ===' as section;

SELECT 
  s.id as shop_id,
  s.shop_name,
  s.owner_id,
  up.first_name || ' ' || up.last_name as owner_name,
  up.email as owner_email
FROM shops s
LEFT JOIN user_profiles up ON up.id = s.owner_id
ORDER BY s.created_at DESC;

-- Check if current user exists in user_profiles
SELECT 
  '=== 👤 USER PROFILE CHECK ===' as section;

SELECT 
  id,
  first_name,
  last_name,
  email,
  user_type,
  shop_id
FROM user_profiles
WHERE id = auth.uid();
