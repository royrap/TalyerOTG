-- ============================================
-- 🔧 FIX TRIGGER - Add proper logging and error handling
-- ============================================

-- First, let's see what's currently in the database
SELECT 
  '📋 CURRENT SERVICE_REQUESTS TRIGGERS:' as info,
  tgname as trigger_name,
  tgenabled as is_enabled,
  pg_get_triggerdef(oid) as full_definition
FROM pg_trigger
WHERE tgrelid = 'service_requests'::regclass
ORDER BY tgname;

-- Check the trigger function
SELECT 
  '📋 TRIGGER FUNCTION SOURCE:' as info,
  pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname = 'trigger_auto_broadcast_request';

-- ============================================
-- Drop and recreate with better error handling
-- ============================================

DROP TRIGGER IF EXISTS auto_broadcast_new_request ON service_requests;

CREATE OR REPLACE FUNCTION trigger_auto_broadcast_request()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_result JSONB;
  v_error TEXT;
BEGIN
  -- Only broadcast for NEW 'pending' requests
  IF NEW.status = 'pending' AND (OLD.status IS NULL OR OLD IS NULL) THEN
    
    RAISE NOTICE '🚀 ===== TRIGGER FIRED =====';
    RAISE NOTICE '🚀 Request ID: %', NEW.id;
    RAISE NOTICE '🚀 Request Type: %', NEW.request_type;
    RAISE NOTICE '🚀 Preferred Shop ID: %', NEW.preferred_shop_id;
    RAISE NOTICE '🚀 Status: %', NEW.status;
    
    BEGIN
      -- Call the broadcast function
      v_result := broadcast_service_request_with_shop_filter(NEW.id);
      
      RAISE NOTICE '📊 ===== BROADCAST RESULT =====';
      RAISE NOTICE '📊 %', v_result;
      RAISE NOTICE '📊 =============================';
      
    EXCEPTION
      WHEN OTHERS THEN
        v_error := SQLERRM;
        RAISE NOTICE '❌ ===== BROADCAST ERROR =====';
        RAISE NOTICE '❌ Error: %', v_error;
        RAISE NOTICE '❌ ============================';
        
        -- Don't fail the insert, just log the error
        RAISE WARNING 'Broadcast function failed: %', v_error;
    END;
    
  ELSE
    RAISE NOTICE '⏭️ Trigger skipped - Status: % (OLD: %)', NEW.status, COALESCE(OLD.status, 'NULL');
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create the trigger AFTER INSERT
CREATE TRIGGER auto_broadcast_new_request
AFTER INSERT ON service_requests
FOR EACH ROW
EXECUTE FUNCTION trigger_auto_broadcast_request();

-- Verify installation
SELECT 
  '✅ TRIGGER REINSTALLED:' as info,
  tgname as trigger_name,
  tgenabled as is_enabled,
  CASE tgtype & 2 
    WHEN 2 THEN 'BEFORE'
    ELSE 'AFTER'
  END as timing,
  CASE tgtype & 4
    WHEN 4 THEN 'INSERT'
    ELSE 'OTHER'
  END as event
FROM pg_trigger
WHERE tgrelid = 'service_requests'::regclass
  AND tgname = 'auto_broadcast_new_request';

SELECT '🎉 Trigger fixed! Now try creating a service request again and check Supabase logs.' as status;
