-- ROADAID SYSTEM KEY TABLES ANALYSIS
-- This query analyzes the core tables actively used by the RoadAid Flutter application
-- Based on code analysis, these are the most frequently accessed tables

-- =======================
-- 📊 COMPLETE ANALYSIS WITH SUMMARY
-- =======================
WITH main_analysis AS (
  -- PRIMARY TABLES
  SELECT 'service_requests' as table_name, 'PRIMARY - Core service workflow' as importance, COUNT(*) as record_count, 1 as sort_order
  FROM service_requests
  UNION ALL
  SELECT 'user_profiles' as table_name, 'PRIMARY - User management system' as importance, COUNT(*) as record_count, 1 as sort_order
  FROM user_profiles
  UNION ALL
  SELECT 'service_providers' as table_name, 'PRIMARY - Service provider system' as importance, COUNT(*) as record_count, 1 as sort_order
  FROM service_providers
  UNION ALL
  SELECT 'shops' as table_name, 'PRIMARY - Shop management system' as importance, COUNT(*) as record_count, 1 as sort_order
  FROM shops
  UNION ALL
  SELECT 'invoices' as table_name, 'PRIMARY - Payment processing' as importance, COUNT(*) as record_count, 1 as sort_order
  FROM invoices
  UNION ALL
  
  -- SECONDARY TABLES
  SELECT 'request_routing' as table_name, 'SECONDARY - Request routing logic' as importance, COUNT(*) as record_count, 2 as sort_order
  FROM request_routing
  UNION ALL
  SELECT 'request_broadcasts' as table_name, 'SECONDARY - Request broadcasting' as importance, COUNT(*) as record_count, 2 as sort_order
  FROM request_broadcasts
  UNION ALL
  SELECT 'mechanic_availability_status' as table_name, 'SECONDARY - Mechanic availability tracking' as importance, COUNT(*) as record_count, 2 as sort_order
  FROM mechanic_availability_status
  UNION ALL
  SELECT 'shop_mechanics' as table_name, 'SECONDARY - Shop-mechanic associations' as importance, COUNT(*) as record_count, 2 as sort_order
  FROM shop_mechanics
  UNION ALL
  SELECT 'request_status_history' as table_name, 'SECONDARY - Service request history' as importance, COUNT(*) as record_count, 2 as sort_order
  FROM request_status_history
  UNION ALL
  SELECT 'vehicles' as table_name, 'SECONDARY - Customer vehicle data' as importance, COUNT(*) as record_count, 2 as sort_order
  FROM vehicles
  UNION ALL
  SELECT 'inspection_reports' as table_name, 'SECONDARY - Inspection documentation' as importance, COUNT(*) as record_count, 2 as sort_order
  FROM inspection_reports
  UNION ALL
  
  -- SUPPORTING TABLES
  SELECT 'notifications' as table_name, 'SUPPORTING - Notification system' as importance, COUNT(*) as record_count, 3 as sort_order
  FROM notifications
  UNION ALL
  SELECT 'user_locations' as table_name, 'SUPPORTING - Location services' as importance, COUNT(*) as record_count, 3 as sort_order
  FROM user_locations
  UNION ALL
  SELECT 'service_categories' as table_name, 'SUPPORTING - Service categorization' as importance, COUNT(*) as record_count, 3 as sort_order
  FROM service_categories
  UNION ALL
  SELECT 'shop_services' as table_name, 'SUPPORTING - Shop service catalog' as importance, COUNT(*) as record_count, 3 as sort_order
  FROM shop_services
  UNION ALL
  SELECT 'talyer_owner_verifications' as table_name, 'SUPPORTING - Owner verification system' as importance, COUNT(*) as record_count, 3 as sort_order
  FROM talyer_owner_verifications
  UNION ALL
  SELECT 'payments' as table_name, 'SUPPORTING - Payment transaction logs' as importance, COUNT(*) as record_count, 3 as sort_order
  FROM payments
),
summary_stats AS (
  SELECT 
    (SELECT COUNT(*) FROM service_requests) +
    (SELECT COUNT(*) FROM user_profiles) +
    (SELECT COUNT(*) FROM service_providers) +
    (SELECT COUNT(*) FROM shops) +
    (SELECT COUNT(*) FROM invoices) as total_primary_records
),
combined_results AS (
  -- Main table data
  SELECT table_name, importance, record_count, sort_order
  FROM main_analysis

  UNION ALL

  -- Summary information
  SELECT 
    '=== SUMMARY ===' as table_name,
    'ANALYSIS COMPLETE' as importance,
    (SELECT total_primary_records FROM summary_stats) as record_count,
    4 as sort_order

  UNION ALL

  SELECT 
    'TOTAL PRIMARY TABLES' as table_name,
    '5 tables identified' as importance,
    0 as record_count,
    5 as sort_order

  UNION ALL

  SELECT 
    'TOTAL SECONDARY TABLES' as table_name,
    '7 tables identified' as importance,
    0 as record_count,
    6 as sort_order

  UNION ALL

  SELECT 
    'TOTAL SUPPORTING TABLES' as table_name,
    '6 tables identified' as importance,
    0 as record_count,
    7 as sort_order

  UNION ALL

  SELECT 
    'ROADAID SYSTEM STATUS' as table_name,
    'OPERATIONAL & ACTIVE' as importance,
    0 as record_count,
    8 as sort_order
)
SELECT table_name, importance, record_count
FROM combined_results
ORDER BY sort_order, record_count DESC;