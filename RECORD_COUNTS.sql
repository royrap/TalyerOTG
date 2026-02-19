-- QUICK RECORD COUNT FOR ALL TABLES
-- Shows how many records each table has

-- === RECORD COUNTS SUMMARY ===
SELECT 
  'user_profiles' as table_name, 
  (SELECT COUNT(*) FROM user_profiles) as record_count
UNION ALL
SELECT 
  'service_requests' as table_name, 
  (SELECT COUNT(*) FROM service_requests) as record_count
UNION ALL
SELECT 
  'shops' as table_name, 
  (SELECT COUNT(*) FROM shops) as record_count
UNION ALL
SELECT 
  'invoices' as table_name, 
  (SELECT COUNT(*) FROM invoices) as record_count
UNION ALL
SELECT 
  'payments' as table_name, 
  (SELECT COUNT(*) FROM payments) as record_count
UNION ALL
SELECT 
  'mechanics' as table_name, 
  (SELECT COUNT(*) FROM mechanics) as record_count
UNION ALL
SELECT 
  'vehicles' as table_name, 
  (SELECT COUNT(*) FROM vehicles) as record_count
UNION ALL
SELECT 
  'service_providers' as table_name, 
  (SELECT COUNT(*) FROM service_providers) as record_count
UNION ALL
SELECT 
  'service_categories' as table_name, 
  (SELECT COUNT(*) FROM service_categories) as record_count
UNION ALL
SELECT 
  'shop_services' as table_name, 
  (SELECT COUNT(*) FROM shop_services) as record_count
UNION ALL
SELECT 
  'job_completion_codes' as table_name, 
  (SELECT COUNT(*) FROM job_completion_codes) as record_count
UNION ALL
SELECT 
  'service_completions' as table_name, 
  (SELECT COUNT(*) FROM service_completions) as record_count
UNION ALL
SELECT 
  'notifications' as table_name, 
  (SELECT COUNT(*) FROM notifications) as record_count
UNION ALL
SELECT 
  'messages' as table_name, 
  (SELECT COUNT(*) FROM messages) as record_count
UNION ALL
SELECT 
  'request_broadcasts' as table_name, 
  (SELECT COUNT(*) FROM request_broadcasts) as record_count
UNION ALL
SELECT 
  'audit_logs' as table_name, 
  (SELECT COUNT(*) FROM audit_logs) as record_count
ORDER BY record_count DESC;