-- ============================================
-- 🔧 FIX: Remove old trigger that calls wrong function
-- ============================================

-- Check what triggers exist on service_requests
SELECT 
  '📋 CURRENT TRIGGERS ON service_requests:' as info,
  tgname as trigger_name,
  pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger
WHERE tgrelid = 'service_requests'::regclass
ORDER BY tgname;

-- Drop ALL triggers on service_requests
DROP TRIGGER IF EXISTS broadcast_service_request_trigger ON service_requests;
DROP TRIGGER IF EXISTS auto_broadcast_service_request ON service_requests;
DROP TRIGGER IF EXISTS broadcast_request_trigger ON service_requests;
DROP TRIGGER IF EXISTS auto_broadcast_new_request ON service_requests;

-- Drop the OLD function (different signature)
DROP FUNCTION IF EXISTS broadcast_service_request(text, numeric, numeric, numeric, character varying, boolean) CASCADE;
DROP FUNCTION IF EXISTS broadcast_service_request CASCADE;

-- Recreate ONLY the correct trigger
CREATE TRIGGER auto_broadcast_new_request
AFTER INSERT ON service_requests
FOR EACH ROW
EXECUTE FUNCTION trigger_auto_broadcast_request();

-- Verify
SELECT 
  '✅ UPDATED TRIGGERS:' as info,
  tgname as trigger_name
FROM pg_trigger
WHERE tgrelid = 'service_requests'::regclass
ORDER BY tgname;

SELECT '🎉 FIXED! Now test creating a service request again.' as status;
