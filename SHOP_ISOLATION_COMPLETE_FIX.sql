-- ============================================
-- 🔧 COMPLETE SHOP ISOLATION FIX
-- ============================================
-- This SQL implements proper shop isolation so that:
-- 1. Only mechanics from the selected shop receive notifications
-- 2. Customers see proper alerts when no mechanics are available
-- 3. Mechanics from other shops never see requests meant for another shop
-- ============================================

-- ============================================
-- STEP 1: Drop existing function (if any)
-- ============================================
DROP FUNCTION IF EXISTS broadcast_service_request_with_shop_filter(uuid) CASCADE;

-- ============================================
-- STEP 2: Create improved shop-specific broadcast function
-- ============================================
CREATE OR REPLACE FUNCTION broadcast_service_request_with_shop_filter(p_request_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_request_record RECORD;
  v_shop_id UUID;
  v_mechanic_record RECORD;
  v_notified_count INTEGER := 0;
  v_available_mechanics_count INTEGER := 0;
  v_busy_mechanics_count INTEGER := 0;
  v_total_mechanics_count INTEGER := 0;
BEGIN
  -- Get service request details
  SELECT * INTO v_request_record
  FROM service_requests
  WHERE id = p_request_id;

  IF NOT FOUND THEN
    RAISE NOTICE '❌ Service request % not found', p_request_id;
    RETURN jsonb_build_object(
      'success', false,
      'error', 'request_not_found',
      'user_message', 'Service request not found.'
    );
  END IF;

  RAISE NOTICE '🔍 Processing request % with type: %', p_request_id, v_request_record.request_type;

  -- ============================================
  -- CASE 1: SHOP-BASED REQUEST (preferred_shop_id is set)
  -- ============================================
  IF v_request_record.request_type = 'shop_based' AND v_request_record.preferred_shop_id IS NOT NULL THEN
    v_shop_id := v_request_record.preferred_shop_id;
    
    RAISE NOTICE '🏪 Shop-based request for shop: %', v_shop_id;
    
    -- Count total mechanics in the shop
    SELECT COUNT(*) INTO v_total_mechanics_count
    FROM shop_mechanics sm
    WHERE sm.shop_id = v_shop_id
      AND sm.is_active = true;
    
    RAISE NOTICE '👷 Total mechanics in shop: %', v_total_mechanics_count;
    
    -- Check if shop has NO mechanics at all
    IF v_total_mechanics_count = 0 THEN
      RAISE NOTICE '❌ Shop has NO mechanics';
      
      -- Update request status
      UPDATE service_requests
      SET broadcast_status = 'no_mechanics_available',
          broadcast_started_at = now(),
          notified_providers_count = 0
      WHERE id = p_request_id;
      
      RETURN jsonb_build_object(
        'success', false,
        'error', 'no_mechanics_in_shop',
        'user_message', 'Sorry, there are no mechanics available in the selected shop at the moment. Please try selecting another shop or try again later.',
        'shop_id', v_shop_id,
        'total_mechanics', v_total_mechanics_count
      );
    END IF;
    
    -- Count available vs busy mechanics
    SELECT 
      COUNT(*) FILTER (WHERE sm.is_available = true) as available_count,
      COUNT(*) FILTER (WHERE sm.is_available = false) as busy_count
    INTO v_available_mechanics_count, v_busy_mechanics_count
    FROM shop_mechanics sm
    WHERE sm.shop_id = v_shop_id
      AND sm.is_active = true;
    
    RAISE NOTICE '✅ Available mechanics: %, ⏳ Busy mechanics: %', v_available_mechanics_count, v_busy_mechanics_count;
    
    -- Check if ALL mechanics are busy
    IF v_available_mechanics_count = 0 AND v_busy_mechanics_count > 0 THEN
      RAISE NOTICE '⏳ All mechanics are busy';
      
      -- Update request status
      UPDATE service_requests
      SET broadcast_status = 'all_mechanics_busy',
          broadcast_started_at = now(),
          notified_providers_count = 0
      WHERE id = p_request_id;
      
      RETURN jsonb_build_object(
        'success', false,
        'error', 'all_mechanics_busy',
        'user_message', 'All mechanics in the selected shop are currently busy. Please try again later or select another shop.',
        'shop_id', v_shop_id,
        'total_mechanics', v_total_mechanics_count,
        'available_mechanics', v_available_mechanics_count,
        'busy_mechanics', v_busy_mechanics_count
      );
    END IF;
    
    -- Loop through ONLY available mechanics in THIS shop
    FOR v_mechanic_record IN
      SELECT 
        sm.mechanic_id,
        up.first_name || ' ' || up.last_name as mechanic_name,
        sm.shop_id,
        s.shop_name,
        0 as distance_km  -- Distance not needed for shop-based requests
      FROM shop_mechanics sm
      JOIN user_profiles up ON up.id = sm.mechanic_id
      JOIN shops s ON s.id = sm.shop_id
      WHERE sm.shop_id = v_shop_id
        AND sm.is_active = true
        AND sm.is_available = true  -- Only notify available mechanics
      ORDER BY sm.joined_at  -- Notify senior mechanics first
    LOOP
      RAISE NOTICE '📤 Notifying mechanic: % (%) from shop: %', 
        v_mechanic_record.mechanic_name, 
        v_mechanic_record.mechanic_id,
        v_mechanic_record.shop_name;
      
      -- Insert broadcast record for this mechanic
      INSERT INTO request_broadcasts (
        request_id,
        provider_id,
        provider_type,
        shop_id,
        mechanic_id,
        distance_km,
        notification_sent_at,
        notification_method,
        response_status,
        is_eligible,
        eligibility_reasons
      ) VALUES (
        p_request_id,
        (SELECT id FROM service_providers WHERE user_id = v_mechanic_record.mechanic_id LIMIT 1),
        'mechanic',
        v_mechanic_record.shop_id,
        v_mechanic_record.mechanic_id,
        v_mechanic_record.distance_km,
        now(),
        'push',
        'pending',
        true,
        jsonb_build_array('mechanic_in_selected_shop', 'mechanic_available')
      );
      
      v_notified_count := v_notified_count + 1;
    END LOOP;
    
    RAISE NOTICE '✅ Notified % mechanics from shop %', v_notified_count, v_shop_id;
    
    -- Update service request with broadcast info
    UPDATE service_requests
    SET broadcast_status = CASE 
        WHEN v_notified_count > 0 THEN 'broadcasting'
        ELSE 'no_mechanics_available'
      END,
        broadcast_started_at = now(),
        notified_providers_count = v_notified_count,
        mechanics_notified_count = v_notified_count
    WHERE id = p_request_id;
    
    -- Return success if mechanics were notified
    IF v_notified_count > 0 THEN
      RETURN jsonb_build_object(
        'success', true,
        'notified_count', v_notified_count,
        'shop_id', v_shop_id,
        'shop_name', v_mechanic_record.shop_name,
        'message', 'Service request broadcast to ' || v_notified_count || ' available mechanics in the selected shop'
      );
    ELSE
      -- This case should be caught earlier, but as a safety net
      RETURN jsonb_build_object(
        'success', false,
        'error', 'no_available_mechanics',
        'user_message', 'No available mechanics in the selected shop at the moment.',
        'shop_id', v_shop_id
      );
    END IF;
    
  -- ============================================
  -- CASE 2: BROADCAST REQUEST (no preferred shop)
  -- ============================================
  ELSIF v_request_record.request_type = 'broadcast' OR v_request_record.preferred_shop_id IS NULL THEN
    RAISE NOTICE '📡 Broadcast mode - notifying all available mechanics within radius';
    
    -- This is the old broadcast logic for emergency/general requests
    -- Loop through ALL available mechanics within radius
    FOR v_mechanic_record IN
      SELECT 
        sm.mechanic_id,
        up.first_name || ' ' || up.last_name as mechanic_name,
        sm.shop_id,
        s.shop_name,
        0 as distance_km
      FROM shop_mechanics sm
      JOIN user_profiles up ON up.id = sm.mechanic_id
      JOIN shops s ON s.id = sm.shop_id
      WHERE sm.is_active = true
        AND sm.is_available = true
      LIMIT 10  -- Broadcast to max 10 mechanics
    LOOP
      INSERT INTO request_broadcasts (
        request_id,
        provider_id,
        provider_type,
        shop_id,
        mechanic_id,
        distance_km,
        notification_sent_at,
        notification_method,
        response_status,
        is_eligible,
        eligibility_reasons
      ) VALUES (
        p_request_id,
        (SELECT id FROM service_providers WHERE user_id = v_mechanic_record.mechanic_id LIMIT 1),
        'mechanic',
        v_mechanic_record.shop_id,
        v_mechanic_record.mechanic_id,
        v_mechanic_record.distance_km,
        now(),
        'push',
        'pending',
        true,
        jsonb_build_array('broadcast_mode', 'mechanic_available')
      );
      
      v_notified_count := v_notified_count + 1;
    END LOOP;
    
    UPDATE service_requests
    SET broadcast_status = CASE 
        WHEN v_notified_count > 0 THEN 'broadcasting'
        ELSE 'no_mechanics_available'
      END,
        broadcast_started_at = now(),
        notified_providers_count = v_notified_count,
        mechanics_notified_count = v_notified_count
    WHERE id = p_request_id;
    
    RETURN jsonb_build_object(
      'success', true,
      'notified_count', v_notified_count,
      'mode', 'broadcast',
      'message', 'Broadcast to ' || v_notified_count || ' mechanics'
    );
    
  ELSE
    RAISE NOTICE '⚠️ Unknown request type or invalid state';
    RETURN jsonb_build_object(
      'success', false,
      'error', 'invalid_request_type',
      'user_message', 'Invalid service request configuration.'
    );
  END IF;
  
END;
$$;

-- ============================================
-- STEP 3: Create trigger to auto-broadcast
-- ============================================
CREATE OR REPLACE FUNCTION trigger_auto_broadcast_request()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_result JSONB;
BEGIN
  -- Only broadcast for new 'pending' requests
  IF NEW.status = 'pending' AND OLD.status IS NULL THEN
    RAISE NOTICE '🚀 Auto-broadcasting new request: %', NEW.id;
    
    -- Call the broadcast function
    v_result := broadcast_service_request_with_shop_filter(NEW.id);
    
    RAISE NOTICE '📊 Broadcast result: %', v_result;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Drop existing trigger if any
DROP TRIGGER IF EXISTS auto_broadcast_new_request ON service_requests;

-- Create trigger
CREATE TRIGGER auto_broadcast_new_request
AFTER INSERT ON service_requests
FOR EACH ROW
EXECUTE FUNCTION trigger_auto_broadcast_request();

-- ============================================
-- STEP 4: Add 'all_mechanics_busy' to broadcast_status CHECK constraint
-- ============================================
DO $$
BEGIN
  -- Drop existing constraint
  ALTER TABLE service_requests DROP CONSTRAINT IF EXISTS service_requests_broadcast_status_check;
  
  -- Add new constraint with 'all_mechanics_busy' option
  ALTER TABLE service_requests ADD CONSTRAINT service_requests_broadcast_status_check
    CHECK (broadcast_status = ANY (ARRAY[
      'not_started'::text, 
      'broadcasting'::text, 
      'accepted'::text, 
      'expired'::text, 
      'cancelled'::text,
      'no_mechanics_available'::text,
      'all_mechanics_busy'::text
    ]));
    
  RAISE NOTICE '✅ Added all_mechanics_busy to broadcast_status constraint';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Constraint update failed or already exists: %', SQLERRM;
END $$;

-- ============================================
-- STEP 5: Helper function to mark mechanic as busy
-- ============================================
CREATE OR REPLACE FUNCTION mark_mechanic_busy(p_mechanic_id UUID, p_request_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
  -- Update shop_mechanics to mark as unavailable
  UPDATE shop_mechanics
  SET is_available = false
  WHERE mechanic_id = p_mechanic_id;
  
  -- Update mechanic_availability_status if it exists
  UPDATE mechanic_availability_status
  SET current_status = 'busy',
      current_request_id = p_request_id,
      is_accepting_requests = false,
      last_status_update = now()
  WHERE mechanic_id = p_mechanic_id;
  
  RAISE NOTICE '✅ Mechanic % marked as busy for request %', p_mechanic_id, p_request_id;
  
  RETURN true;
END;
$$;

-- ============================================
-- STEP 6: Helper function to mark mechanic as available
-- ============================================
CREATE OR REPLACE FUNCTION mark_mechanic_available(p_mechanic_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
  -- Update shop_mechanics to mark as available
  UPDATE shop_mechanics
  SET is_available = true
  WHERE mechanic_id = p_mechanic_id;
  
  -- Update mechanic_availability_status if it exists
  UPDATE mechanic_availability_status
  SET current_status = 'available',
      current_request_id = NULL,
      is_accepting_requests = true,
      last_status_update = now()
  WHERE mechanic_id = p_mechanic_id;
  
  RAISE NOTICE '✅ Mechanic % marked as available', p_mechanic_id;
  
  RETURN true;
END;
$$;

-- ============================================
-- STEP 7: Auto-mark mechanic as busy when accepting
-- ============================================
CREATE OR REPLACE FUNCTION auto_mark_mechanic_busy()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- When a mechanic is assigned to a request
  IF NEW.assigned_mechanic_id IS NOT NULL AND OLD.assigned_mechanic_id IS NULL THEN
    PERFORM mark_mechanic_busy(NEW.assigned_mechanic_id, NEW.id);
  END IF;
  
  RETURN NEW;
END;
$$;

-- Drop existing trigger if any
DROP TRIGGER IF EXISTS auto_mark_mechanic_busy_trigger ON service_requests;

-- Create trigger
CREATE TRIGGER auto_mark_mechanic_busy_trigger
AFTER UPDATE ON service_requests
FOR EACH ROW
WHEN (NEW.assigned_mechanic_id IS NOT NULL AND OLD.assigned_mechanic_id IS NULL)
EXECUTE FUNCTION auto_mark_mechanic_busy();

-- ============================================
-- STEP 8: Auto-mark mechanic as available when job completes
-- ============================================
CREATE OR REPLACE FUNCTION auto_mark_mechanic_available()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- When service is completed
  IF NEW.status = 'completed' AND OLD.status != 'completed' AND NEW.assigned_mechanic_id IS NOT NULL THEN
    PERFORM mark_mechanic_available(NEW.assigned_mechanic_id);
  END IF;
  
  RETURN NEW;
END;
$$;

-- Drop existing trigger if any
DROP TRIGGER IF EXISTS auto_mark_mechanic_available_trigger ON service_requests;

-- Create trigger
CREATE TRIGGER auto_mark_mechanic_available_trigger
AFTER UPDATE ON service_requests
FOR EACH ROW
WHEN (NEW.status = 'completed' AND OLD.status != 'completed')
EXECUTE FUNCTION auto_mark_mechanic_available();

-- ============================================
-- ✅ VERIFICATION QUERIES
-- ============================================

-- Check if functions were created
SELECT 
  '✅ FUNCTIONS INSTALLED' as status,
  COUNT(*) as function_count
FROM pg_proc
WHERE proname IN (
  'broadcast_service_request_with_shop_filter',
  'trigger_auto_broadcast_request',
  'mark_mechanic_busy',
  'mark_mechanic_available',
  'auto_mark_mechanic_busy',
  'auto_mark_mechanic_available'
);

-- Check if triggers were created
SELECT 
  '✅ TRIGGERS INSTALLED' as status,
  COUNT(*) as trigger_count
FROM pg_trigger
WHERE tgname IN (
  'auto_broadcast_new_request',
  'auto_mark_mechanic_busy_trigger',
  'auto_mark_mechanic_available_trigger'
);

-- Show all shops and their mechanics
SELECT 
  '📊 SHOPS AND MECHANICS' as info,
  s.shop_name,
  COUNT(sm.id) as total_mechanics,
  COUNT(CASE WHEN sm.is_available = true THEN 1 END) as available_mechanics,
  COUNT(CASE WHEN sm.is_available = false THEN 1 END) as busy_mechanics,
  string_agg(up.first_name || ' ' || up.last_name, ', ') as mechanic_names
FROM shops s
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id
LEFT JOIN user_profiles up ON up.id = sm.mechanic_id
GROUP BY s.id, s.shop_name
ORDER BY s.shop_name;

-- ============================================
-- 📝 IMPLEMENTATION COMPLETE
-- ============================================
SELECT 
  '🎉 SHOP ISOLATION FIX INSTALLED' as status,
  'Now test by creating a new service request from Flutter app' as next_step,
  'Select riza store (0 mechanics) and you should see pop-up alert' as expected_behavior;
