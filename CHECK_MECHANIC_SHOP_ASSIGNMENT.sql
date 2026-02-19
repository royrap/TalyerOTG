-- ============================================================================
-- CHECK MECHANIC SHOP ASSIGNMENT
-- ============================================================================
-- This script checks the mechanic's current shop assignment and identifies
-- any mismatches causing acceptance failures.
-- ============================================================================

-- 1. Check mechanic's shop assignment
SELECT 
  'MECHANIC SHOP ASSIGNMENT' as check_type,
  sm.mechanic_id,
  sm.shop_id,
  s.business_name as shop_name,
  s.business_permit_status,
  sm.created_at
FROM shop_mechanics sm
JOIN shops s ON s.id = sm.shop_id
WHERE sm.mechanic_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c';

-- 2. Check the failed requests' shop IDs
SELECT 
  'FAILED REQUEST SHOPS' as check_type,
  sr.id as request_id,
  sr.shop_id,
  s.business_name as shop_name,
  sr.status,
  sr.created_at
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.shop_id
WHERE sr.id IN (
  '3e558347-4620-4321-9512-637d5646e400',
  '667fc672-6ded-41af-b707-493c9d8a595f',
  '86886451-800b-49e3-8bcb-e5afbbe49b7a'
)
ORDER BY sr.created_at DESC;

-- 3. Check if there are multiple shop assignments
SELECT 
  'MULTIPLE ASSIGNMENTS CHECK' as check_type,
  COUNT(*) as assignment_count
FROM shop_mechanics
WHERE mechanic_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c';

-- 4. List ALL shops to see which one to use
SELECT 
  'ALL SHOPS' as check_type,
  id as shop_id,
  business_name as shop_name,
  business_permit_status,
  city,
  created_at
FROM shops
ORDER BY created_at DESC;

-- ============================================================================
-- EXPECTED RESULTS:
-- - Should show mechanic's current shop assignment (if any)
-- - Should show which shops the failed requests belong to
-- - Should reveal if there's a shop mismatch
-- ============================================================================
