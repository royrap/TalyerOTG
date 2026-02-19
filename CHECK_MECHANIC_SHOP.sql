-- ============================================
-- CHECK: Saan shop naka-base si Rafaels pineda?
-- ============================================

-- 1. Find Rafaels pineda's mechanic info
SELECT 
  '👷 Mechanic Info' as info,
  up.id as mechanic_id,
  up.first_name || ' ' || up.last_name as mechanic_name,
  up.email,
  sm.shop_id,
  s.shop_name,
  sm.is_available,
  sm.is_active
FROM user_profiles up
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id
LEFT JOIN shops s ON s.id = sm.shop_id
WHERE up.first_name ILIKE '%rafael%' 
   OR up.last_name ILIKE '%pineda%';

-- 2. Check ALL mechanics and their shops
SELECT 
  '🏪 ALL Mechanics and Shops' as info,
  up.first_name || ' ' || up.last_name as mechanic_name,
  s.shop_name,
  sm.is_available,
  sm.is_active
FROM shop_mechanics sm
JOIN user_profiles up ON up.id = sm.mechanic_id
JOIN shops s ON s.id = sm.shop_id
ORDER BY s.shop_name, up.last_name;

-- 3. Check which shop has which mechanics
SELECT 
  '📊 Mechanics per Shop' as info,
  s.shop_name,
  s.id as shop_id,
  COUNT(sm.mechanic_id) as mechanic_count,
  string_agg(up.first_name || ' ' || up.last_name, ', ') as mechanics
FROM shops s
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id AND sm.is_active = true
LEFT JOIN user_profiles up ON up.id = sm.mechanic_id
GROUP BY s.id, s.shop_name
ORDER BY s.shop_name;

-- 4. Check riza store vs MechAid shop IDs
SELECT 
  '🆔 Shop IDs' as info,
  shop_name,
  id as shop_id
FROM shops
WHERE shop_name ILIKE '%riza%' OR shop_name ILIKE '%mechaid%'
ORDER BY shop_name;
