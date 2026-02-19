-- Check what request_type was saved
SELECT 
  'Request Type Check' as info,
  request_type,
  preferred_shop_id,
  is_broadcast_request,
  created_at
FROM service_requests
ORDER BY created_at DESC
LIMIT 1;
