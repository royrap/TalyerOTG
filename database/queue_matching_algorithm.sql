-- ============================================
-- QUEUE MATCHING ALGORITHM IMPLEMENTATION
-- Smart Request-Mechanic Matching System
-- ============================================

-- ============================================
-- FUNCTION: Create Service Request Queue Entry
-- Called when a new service request is created
-- ============================================
CREATE OR REPLACE FUNCTION create_service_request_queue_entry(
  p_request_id UUID,
  p_category_id UUID DEFAULT NULL,
  p_urgency_level TEXT DEFAULT 'normal',
  p_max_distance_km DECIMAL DEFAULT 50.0
)
RETURNS UUID AS $$
DECLARE
  v_queue_id UUID;
  v_priority_score DECIMAL;
  v_required_skills JSONB;
  v_customer_location GEOGRAPHY;
  v_expires_at TIMESTAMPTZ;
BEGIN
  -- Get customer location from request
  SELECT ST_MakePoint(pickup_longitude, pickup_latitude)::geography
  INTO v_customer_location
  FROM service_requests
  WHERE id = p_request_id;
  
  -- Get required skills from category
  IF p_category_id IS NOT NULL THEN
    SELECT jsonb_build_array(name)
    INTO v_required_skills
    FROM service_categories
    WHERE id = p_category_id;
  END IF;
  
  -- Calculate priority score based on urgency
  v_priority_score := CASE p_urgency_level
    WHEN 'emergency' THEN 200.00
    WHEN 'high' THEN 150.00
    WHEN 'normal' THEN 100.00
    WHEN 'low' THEN 50.00
    ELSE 100.00
  END;
  
  -- Set expiration based on urgency
  v_expires_at := CASE p_urgency_level
    WHEN 'emergency' THEN NOW() + INTERVAL '15 minutes'
    WHEN 'high' THEN NOW() + INTERVAL '30 minutes'
    WHEN 'normal' THEN NOW() + INTERVAL '1 hour'
    WHEN 'low' THEN NOW() + INTERVAL '2 hours'
    ELSE NOW() + INTERVAL '1 hour'
  END;
  
  -- Create queue entry
  INSERT INTO service_request_queue (
    request_id,
    priority_score,
    required_skills,
    preferred_location,
    max_distance_km,
    urgency_level,
    is_active,
    expires_at
  ) VALUES (
    p_request_id,
    v_priority_score,
    v_required_skills,
    v_customer_location,
    p_max_distance_km,
    p_urgency_level,
    TRUE,
    v_expires_at
  )
  ON CONFLICT (request_id) DO UPDATE SET
    priority_score = EXCLUDED.priority_score,
    urgency_level = EXCLUDED.urgency_level,
    expires_at = EXCLUDED.expires_at,
    is_active = TRUE,
    updated_at = NOW()
  RETURNING id INTO v_queue_id;
  
  RETURN v_queue_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Find Best Mechanic Match
-- Returns the single best mechanic for a request
-- ============================================
CREATE OR REPLACE FUNCTION find_best_mechanic_match(
  p_request_id UUID,
  p_exclude_declined BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
  mechanic_id UUID,
  mechanic_name TEXT,
  distance_km DECIMAL,
  priority_score DECIMAL,
  match_confidence DECIMAL,
  phone_number VARCHAR,
  profile_image_url TEXT,
  specializations TEXT[]
) AS $$
DECLARE
  v_customer_lat NUMERIC;
  v_customer_lng NUMERIC;
  v_declined_mechanics UUID[];
BEGIN
  -- Get request location
  SELECT pickup_latitude, pickup_longitude
  INTO v_customer_lat, v_customer_lng
  FROM service_requests
  WHERE id = p_request_id;
  
  -- Get list of mechanics who already declined
  IF p_exclude_declined THEN
    SELECT COALESCE(declined_by_mechanic_ids, ARRAY[]::UUID[])
    INTO v_declined_mechanics
    FROM service_requests
    WHERE id = p_request_id;
  ELSE
    v_declined_mechanics := ARRAY[]::UUID[];
  END IF;
  
  -- Return the best match
  RETURN QUERY
  SELECT 
    grm.mechanic_id,
    grm.mechanic_name,
    grm.distance_km,
    grm.priority_score,
    -- Calculate match confidence (0-100)
    LEAST(100, (
      CASE 
        WHEN grm.priority_score > 250 THEN 95
        WHEN grm.priority_score > 200 THEN 85
        WHEN grm.priority_score > 150 THEN 75
        WHEN grm.priority_score > 100 THEN 60
        ELSE 40
      END
    ))::DECIMAL AS match_confidence,
    grm.phone_number,
    grm.profile_image_url,
    grm.specializations
  FROM get_ranked_mechanics_for_request(p_request_id) AS grm
  WHERE NOT (grm.mechanic_id = ANY(v_declined_mechanics))
  ORDER BY grm.priority_score DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Broadcast Request to Top Mechanics
-- Notifies multiple mechanics simultaneously
-- ============================================
CREATE OR REPLACE FUNCTION broadcast_request_to_mechanics(
  p_request_id UUID,
  p_max_mechanics INTEGER DEFAULT 5,
  p_notification_method TEXT DEFAULT 'push'
)
RETURNS JSONB AS $$
DECLARE
  v_mechanics RECORD;
  v_notified_count INTEGER := 0;
  v_mechanic_ids UUID[] := ARRAY[]::UUID[];
  v_result JSONB;
BEGIN
  -- Get top ranked mechanics
  FOR v_mechanics IN 
    SELECT * FROM get_ranked_mechanics_for_request(p_request_id, 50.0, p_max_mechanics)
  LOOP
    -- Insert broadcast record
    INSERT INTO request_broadcasts (
      request_id,
      provider_id,
      provider_type,
      mechanic_id,
      distance_km,
      notification_sent_at,
      notification_method,
      response_status
    ) VALUES (
      p_request_id,
      v_mechanics.mechanic_id,
      'mechanic',
      v_mechanics.mechanic_id,
      v_mechanics.distance_km,
      NOW(),
      p_notification_method,
      'pending'
    );
    
    -- TODO: Send actual push notification here
    -- PERFORM send_push_notification(v_mechanics.mechanic_id, p_request_id);
    
    v_notified_count := v_notified_count + 1;
    v_mechanic_ids := array_append(v_mechanic_ids, v_mechanics.mechanic_id);
  END LOOP;
  
  -- Update service request
  UPDATE service_requests
  SET
    broadcast_status = 'broadcasting',
    broadcast_started_at = NOW(),
    broadcast_expires_at = NOW() + INTERVAL '30 minutes',
    mechanics_notified_count = v_notified_count,
    updated_at = NOW()
  WHERE id = p_request_id;
  
  -- Update queue
  UPDATE service_request_queue
  SET
    broadcast_count = broadcast_count + 1,
    mechanics_notified = jsonb_build_object(
      'count', v_notified_count,
      'mechanic_ids', v_mechanic_ids,
      'timestamp', NOW()
    ),
    updated_at = NOW()
  WHERE request_id = p_request_id;
  
  v_result := jsonb_build_object(
    'success', TRUE,
    'request_id', p_request_id,
    'mechanics_notified', v_notified_count,
    'mechanic_ids', v_mechanic_ids,
    'message', format('Broadcast sent to %s mechanics', v_notified_count)
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Auto-Match Request to Best Mechanic
-- Complete automated matching workflow
-- ============================================
CREATE OR REPLACE FUNCTION auto_match_request_to_mechanic(
  p_request_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_best_match RECORD;
  v_result JSONB;
  v_request_status TEXT;
BEGIN
  -- Check request status
  SELECT status INTO v_request_status
  FROM service_requests
  WHERE id = p_request_id;
  
  IF v_request_status != 'pending' THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'message', 'Request is not in pending status'
    );
  END IF;
  
  -- Create queue entry if not exists
  PERFORM create_service_request_queue_entry(p_request_id);
  
  -- Find best mechanic match
  SELECT * INTO v_best_match
  FROM find_best_mechanic_match(p_request_id)
  LIMIT 1;
  
  IF v_best_match.mechanic_id IS NULL THEN
    -- No available mechanics, broadcast to multiple
    v_result := broadcast_request_to_mechanics(p_request_id, 5);
    RETURN jsonb_build_object(
      'success', TRUE,
      'match_type', 'broadcast',
      'message', 'No single best match found, broadcasting to multiple mechanics',
      'broadcast_result', v_result
    );
  ELSE
    -- Found best match, notify them
    INSERT INTO request_broadcasts (
      request_id,
      provider_id,
      provider_type,
      mechanic_id,
      distance_km,
      notification_sent_at,
      notification_method,
      response_status
    ) VALUES (
      p_request_id,
      v_best_match.mechanic_id,
      'mechanic',
      v_best_match.mechanic_id,
      v_best_match.distance_km,
      NOW(),
      'push',
      'pending'
    );
    
    -- Update request
    UPDATE service_requests
    SET
      assigned_mechanic_id = v_best_match.mechanic_id,
      status = 'assigned',
      assigned_at = NOW(),
      updated_at = NOW()
    WHERE id = p_request_id;
    
    v_result := jsonb_build_object(
      'success', TRUE,
      'match_type', 'direct',
      'mechanic_id', v_best_match.mechanic_id,
      'mechanic_name', v_best_match.mechanic_name,
      'distance_km', v_best_match.distance_km,
      'priority_score', v_best_match.priority_score,
      'match_confidence', v_best_match.match_confidence,
      'message', 'Best mechanic match found and notified'
    );
    
    RETURN v_result;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Handle Broadcast Response Timeout
-- Re-broadcasts to next batch of mechanics
-- ============================================
CREATE OR REPLACE FUNCTION handle_broadcast_timeout(
  p_request_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_broadcast_count INTEGER;
  v_max_broadcasts INTEGER := 3;
  v_result JSONB;
BEGIN
  -- Get current broadcast count
  SELECT broadcast_count INTO v_broadcast_count
  FROM service_request_queue
  WHERE request_id = p_request_id;
  
  IF v_broadcast_count >= v_max_broadcasts THEN
    -- Max broadcasts reached, mark as no mechanics available
    UPDATE service_requests
    SET
      broadcast_status = 'no_mechanics_available',
      status = 'cancelled',
      updated_at = NOW()
    WHERE id = p_request_id;
    
    UPDATE service_request_queue
    SET
      is_active = FALSE,
      updated_at = NOW()
    WHERE request_id = p_request_id;
    
    RETURN jsonb_build_object(
      'success', FALSE,
      'message', 'Maximum broadcast attempts reached, no mechanics available'
    );
  ELSE
    -- Re-broadcast to next batch
    v_result := broadcast_request_to_mechanics(p_request_id, 5);
    RETURN v_result;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Get Queue Statistics
-- Returns current queue stats for monitoring
-- ============================================
CREATE OR REPLACE FUNCTION get_queue_statistics()
RETURNS TABLE (
  active_requests INTEGER,
  pending_broadcasts INTEGER,
  average_wait_time_minutes DECIMAL,
  total_mechanics_available INTEGER,
  total_mechanics_suspended INTEGER,
  average_queue_score DECIMAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM service_request_queue WHERE is_active = TRUE)::INTEGER,
    (SELECT COUNT(*) FROM service_requests WHERE broadcast_status = 'broadcasting')::INTEGER,
    (SELECT AVG(EXTRACT(EPOCH FROM (NOW() - created_at)) / 60) 
     FROM service_request_queue WHERE is_active = TRUE)::DECIMAL,
    (SELECT COUNT(*) FROM mechanic_queue_scores WHERE is_suspended = FALSE)::INTEGER,
    (SELECT COUNT(*) FROM mechanic_queue_scores WHERE is_suspended = TRUE)::INTEGER,
    (SELECT AVG(total_score) FROM mechanic_queue_scores)::DECIMAL;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Get Mechanic Queue Dashboard
-- Returns detailed queue info for a mechanic
-- ============================================
CREATE OR REPLACE FUNCTION get_mechanic_queue_dashboard(
  p_mechanic_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
  v_queue_score RECORD;
  v_pending_requests INTEGER;
  v_today_stats JSONB;
BEGIN
  -- Get queue score details
  SELECT * INTO v_queue_score
  FROM mechanic_queue_scores
  WHERE mechanic_id = p_mechanic_id;
  
  -- Get pending requests count
  SELECT COUNT(*) INTO v_pending_requests
  FROM request_broadcasts
  WHERE mechanic_id = p_mechanic_id
    AND response_status = 'pending';
  
  -- Build result
  v_result := jsonb_build_object(
    'mechanic_id', p_mechanic_id,
    'queue_score', COALESCE(v_queue_score.total_score, 100.00),
    'base_score', COALESCE(v_queue_score.base_score, 100.00),
    'decline_penalty', COALESCE(v_queue_score.decline_penalty, 0.00),
    'completion_bonus', COALESCE(v_queue_score.completion_bonus, 0.00),
    'rating_bonus', COALESCE(v_queue_score.rating_bonus, 0.00),
    'is_suspended', COALESCE(v_queue_score.is_suspended, FALSE),
    'suspension_ends_at', v_queue_score.suspension_ends_at,
    'today_stats', jsonb_build_object(
      'declines', COALESCE(v_queue_score.declines_today, 0),
      'accepts', COALESCE(v_queue_score.accepts_this_week, 0),
      'consecutive_declines', COALESCE(v_queue_score.consecutive_declines, 0)
    ),
    'pending_requests', v_pending_requests,
    'last_activity', jsonb_build_object(
      'last_decline_at', v_queue_score.last_decline_at,
      'last_accept_at', v_queue_score.last_accept_at
    )
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- SCHEDULED JOBS (Run via pg_cron or external scheduler)
-- ============================================

-- Daily at midnight: Reset decline counters
-- SELECT cron.schedule('reset-daily-declines', '0 0 * * *', 'SELECT reset_daily_decline_counters()');

-- Every 5 minutes: Handle expired broadcasts
CREATE OR REPLACE FUNCTION process_expired_broadcasts()
RETURNS INTEGER AS $$
DECLARE
  v_expired_request RECORD;
  v_processed INTEGER := 0;
BEGIN
  FOR v_expired_request IN
    SELECT request_id
    FROM service_requests
    WHERE broadcast_status = 'broadcasting'
      AND broadcast_expires_at <= NOW()
  LOOP
    PERFORM handle_broadcast_timeout(v_expired_request.request_id);
    v_processed := v_processed + 1;
  END LOOP;
  
  RETURN v_processed;
END;
$$ LANGUAGE plpgsql;

-- SELECT cron.schedule('process-expired-broadcasts', '*/5 * * * *', 'SELECT process_expired_broadcasts()');

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================
CREATE INDEX IF NOT EXISTS idx_request_broadcasts_pending 
  ON request_broadcasts(mechanic_id, response_status) 
  WHERE response_status = 'pending';

CREATE INDEX IF NOT EXISTS idx_service_requests_broadcast_status 
  ON service_requests(broadcast_status, broadcast_expires_at) 
  WHERE broadcast_status = 'broadcasting';

CREATE INDEX IF NOT EXISTS idx_mechanic_location 
  ON user_profiles(current_latitude, current_longitude) 
  WHERE user_type = 'mechanic' AND current_latitude IS NOT NULL;

-- ============================================
-- GRANT PERMISSIONS
-- ============================================
GRANT EXECUTE ON FUNCTION create_service_request_queue_entry TO authenticated;
GRANT EXECUTE ON FUNCTION find_best_mechanic_match TO authenticated;
GRANT EXECUTE ON FUNCTION broadcast_request_to_mechanics TO authenticated;
GRANT EXECUTE ON FUNCTION auto_match_request_to_mechanic TO authenticated;
GRANT EXECUTE ON FUNCTION get_queue_statistics TO authenticated;
GRANT EXECUTE ON FUNCTION get_mechanic_queue_dashboard TO authenticated;

-- ============================================
-- USAGE EXAMPLES
-- ============================================

/*
-- 1. Create a new service request and auto-match
SELECT auto_match_request_to_mechanic('your-request-uuid');

-- 2. Get ranked mechanics for a request
SELECT * FROM get_ranked_mechanics_for_request('your-request-uuid', 50.0, 10);

-- 3. Handle mechanic decline
SELECT handle_mechanic_decline('mechanic-uuid', 'request-uuid', 'Too far away');

-- 4. Handle mechanic accept
SELECT handle_mechanic_accept('mechanic-uuid', 'request-uuid');

-- 5. Get mechanic's queue dashboard
SELECT get_mechanic_queue_dashboard('mechanic-uuid');

-- 6. Get queue statistics
SELECT * FROM get_queue_statistics();

-- 7. Broadcast to multiple mechanics
SELECT broadcast_request_to_mechanics('request-uuid', 5, 'push');

-- 8. Find single best match
SELECT * FROM find_best_mechanic_match('request-uuid', TRUE);
*/
