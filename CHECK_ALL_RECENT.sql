-- Check ALL recent requests and their types
SELECT 
  id,
  request_type,
  preferred_shop_id,
  broadcast_status,
  created_at
FROM service_requests
ORDER BY created_at DESC
LIMIT 5;
