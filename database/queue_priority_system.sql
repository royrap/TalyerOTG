-- ============================================
-- QUEUE PRIORITY SYSTEM
-- Decline Penalty & Mechanic Queue Scoring
-- ============================================

-- Table: Mechanic Queue Scores
-- Tracks decline penalties and bonuses for queue prioritization
CREATE TABLE IF NOT EXISTS public.mechanic_queue_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mechanic_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  
  -- Base scores
  base_score DECIMAL(6,2) NOT NULL DEFAULT 100.00,
  decline_penalty DECIMAL(6,2) NOT NULL DEFAULT 0.00,
  completion_bonus DECIMAL(6,2) NOT NULL DEFAULT 0.00,
  rating_bonus DECIMAL(6,2) NOT NULL DEFAULT 0.00,
  
  -- Computed total score (base - penalty + bonuses)
  total_score DECIMAL(6,2) GENERATED ALWAYS AS (
    base_score - decline_penalty + completion_bonus + rating_bonus
  ) STORED,
  
  -- Decline tracking
  declines_today INTEGER NOT NULL DEFAULT 0,
  declines_this_week INTEGER NOT NULL DEFAULT 0,
  declines_this_month INTEGER NOT NULL DEFAULT 0,
  total_declines INTEGER NOT NULL DEFAULT 0,
  consecutive_declines INTEGER NOT NULL DEFAULT 0,
  last_decline_at TIMESTAMPTZ,
  
  -- Acceptance tracking
  total_accepts INTEGER NOT NULL DEFAULT 0,
  accepts_this_week INTEGER NOT NULL DEFAULT 0,
  last_accept_at TIMESTAMPTZ,
  
  -- Status flags
  is_suspended BOOLEAN NOT NULL DEFAULT FALSE,
  suspension_ends_at TIMESTAMPTZ,
  suspension_reason TEXT,
  
  -- Metadata
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT mechanic_queue_scores_mechanic_id_unique UNIQUE(mechanic_id)
);

-- Indexes for performance
CREATE INDEX idx_mechanic_queue_scores_mechanic ON public.mechanic_queue_scores(mechanic_id);
CREATE INDEX idx_mechanic_queue_scores_total ON public.mechanic_queue_scores(total_score DESC);
CREATE INDEX idx_mechanic_queue_scores_suspended ON public.mechanic_queue_scores(is_suspended) WHERE is_suspended = TRUE;

-- Table: Service Request Queue
-- Enhanced queue management with priority scoring
CREATE TABLE IF NOT EXISTS public.service_request_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
  
  -- Queue metadata
  queue_position INTEGER,
  priority_score DECIMAL(8,2) NOT NULL DEFAULT 100.00,
  
  -- Matching criteria
  required_skills JSONB DEFAULT '[]'::jsonb,
  preferred_location GEOGRAPHY(POINT),
  max_distance_km DECIMAL(6,2) DEFAULT 50.0,
  urgency_level VARCHAR(50) NOT NULL DEFAULT 'normal' 
    CHECK (urgency_level IN ('low', 'normal', 'high', 'emergency')),
  
  -- Broadcast tracking
  broadcast_count INTEGER DEFAULT 0,
  mechanics_notified JSONB DEFAULT '[]'::jsonb,
  mechanics_declined JSONB DEFAULT '[]'::jsonb,
  mechanics_viewed JSONB DEFAULT '[]'::jsonb,
  
  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  matched_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT service_request_queue_request_id_unique UNIQUE(request_id)
);

-- Indexes
CREATE INDEX idx_request_queue_active ON public.service_request_queue(is_active, priority_score DESC) 
  WHERE is_active = TRUE;
CREATE INDEX idx_request_queue_urgency ON public.service_request_queue(urgency_level, created_at);

-- ============================================
-- FUNCTION: Initialize Mechanic Queue Score
-- ============================================
CREATE OR REPLACE FUNCTION initialize_mechanic_queue_score(p_mechanic_id UUID)
RETURNS UUID AS $$
DECLARE
  v_score_id UUID;
  v_rating NUMERIC;
BEGIN
  -- Get mechanic's current rating
  SELECT rating INTO v_rating
  FROM user_profiles
  WHERE id = p_mechanic_id;
  
  -- Insert or update queue score
  INSERT INTO mechanic_queue_scores (
    mechanic_id,
    base_score,
    rating_bonus
  ) VALUES (
    p_mechanic_id,
    100.00,
    CASE
      WHEN v_rating >= 4.5 THEN 20.00
      WHEN v_rating >= 4.0 THEN 10.00
      WHEN v_rating >= 3.5 THEN 5.00
      ELSE 0.00
    END
  )
  ON CONFLICT (mechanic_id) DO UPDATE SET
    rating_bonus = CASE
      WHEN v_rating >= 4.5 THEN 20.00
      WHEN v_rating >= 4.0 THEN 10.00
      WHEN v_rating >= 3.5 THEN 5.00
      ELSE 0.00
    END,
    updated_at = NOW()
  RETURNING id INTO v_score_id;
  
  RETURN v_score_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Handle Mechanic Decline
-- Applies penalties and tracks decline history
-- ============================================
CREATE OR REPLACE FUNCTION handle_mechanic_decline(
  p_mechanic_id UUID,
  p_request_id UUID,
  p_decline_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_declines_today INTEGER;
  v_consecutive_declines INTEGER;
  v_penalty DECIMAL(6,2);
  v_should_suspend BOOLEAN := FALSE;
  v_result JSONB;
BEGIN
  -- Initialize queue score if not exists
  PERFORM initialize_mechanic_queue_score(p_mechanic_id);
  
  -- Update queue score with decline
  UPDATE mechanic_queue_scores
  SET 
    declines_today = declines_today + 1,
    declines_this_week = declines_this_week + 1,
    declines_this_month = declines_this_month + 1,
    total_declines = total_declines + 1,
    consecutive_declines = consecutive_declines + 1,
    last_decline_at = NOW(),
    
    -- Progressive penalty system
    decline_penalty = CASE
      WHEN declines_today >= 8 THEN 80.00  -- Severe penalty (8+ declines)
      WHEN declines_today >= 5 THEN 50.00  -- Heavy penalty (5-7 declines)
      WHEN declines_today >= 3 THEN 25.00  -- Moderate penalty (3-4 declines)
      ELSE decline_penalty + 5.00          -- Regular penalty (+5 per decline)
    END,
    
    -- Check if should suspend
    is_suspended = CASE
      WHEN declines_today >= 5 THEN TRUE
      ELSE is_suspended
    END,
    
    suspension_ends_at = CASE
      WHEN declines_today >= 5 THEN NOW() + INTERVAL '1 hour'
      ELSE suspension_ends_at
    END,
    
    suspension_reason = CASE
      WHEN declines_today >= 5 THEN 'Exceeded daily decline limit (5+ declines)'
      ELSE suspension_reason
    END,
    
    updated_at = NOW()
  WHERE mechanic_id = p_mechanic_id
  RETURNING 
    declines_today,
    consecutive_declines,
    decline_penalty,
    is_suspended
  INTO 
    v_declines_today,
    v_consecutive_declines,
    v_penalty,
    v_should_suspend;
  
  -- Update service request decline tracking
  UPDATE service_requests
  SET 
    decline_count = COALESCE(decline_count, 0) + 1,
    last_declined_at = NOW(),
    decline_reason = p_decline_reason,
    declined_by_mechanic_ids = array_append(
      COALESCE(declined_by_mechanic_ids, ARRAY[]::UUID[]),
      p_mechanic_id
    ),
    updated_at = NOW()
  WHERE id = p_request_id;
  
  -- Update request queue
  UPDATE service_request_queue
  SET
    mechanics_declined = jsonb_set(
      COALESCE(mechanics_declined, '[]'::jsonb),
      ARRAY[jsonb_array_length(COALESCE(mechanics_declined, '[]'::jsonb))::text],
      jsonb_build_object(
        'mechanic_id', p_mechanic_id,
        'declined_at', NOW(),
        'reason', p_decline_reason
      )
    ),
    updated_at = NOW()
  WHERE request_id = p_request_id;
  
  -- Update request broadcast status
  UPDATE request_broadcasts
  SET
    response_status = 'declined',
    responded_at = NOW(),
    decline_reason = p_decline_reason,
    response_time_seconds = EXTRACT(EPOCH FROM (NOW() - notification_sent_at))::INTEGER
  WHERE request_id = p_request_id 
    AND mechanic_id = p_mechanic_id
    AND response_status = 'pending';
  
  -- If suspended, make mechanic unavailable
  IF v_should_suspend THEN
    UPDATE mechanic_availability_status
    SET
      current_status = 'offline',
      is_accepting_requests = FALSE,
      estimated_available_at = NOW() + INTERVAL '1 hour',
      updated_at = NOW()
    WHERE mechanic_id = p_mechanic_id;
  END IF;
  
  -- Log activity
  INSERT INTO mechanic_activity_logs (
    mechanic_id,
    action_type,
    target_type,
    target_id,
    action_details,
    created_at
  ) VALUES (
    p_mechanic_id,
    'request_declined',
    'service_request',
    p_request_id,
    jsonb_build_object(
      'reason', p_decline_reason,
      'declines_today', v_declines_today,
      'consecutive_declines', v_consecutive_declines,
      'penalty_applied', v_penalty,
      'is_suspended', v_should_suspend
    ),
    NOW()
  );
  
  -- Build result
  v_result := jsonb_build_object(
    'success', TRUE,
    'mechanic_id', p_mechanic_id,
    'declines_today', v_declines_today,
    'consecutive_declines', v_consecutive_declines,
    'penalty', v_penalty,
    'is_suspended', v_should_suspend,
    'message', CASE
      WHEN v_should_suspend THEN 'Mechanic suspended for 1 hour due to excessive declines'
      WHEN v_declines_today >= 3 THEN 'Warning: High decline rate today'
      ELSE 'Decline recorded'
    END
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Handle Mechanic Accept
-- Rewards acceptance and resets consecutive declines
-- ============================================
CREATE OR REPLACE FUNCTION handle_mechanic_accept(
  p_mechanic_id UUID,
  p_request_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  -- Initialize queue score if not exists
  PERFORM initialize_mechanic_queue_score(p_mechanic_id);
  
  -- Update queue score with acceptance
  UPDATE mechanic_queue_scores
  SET 
    total_accepts = total_accepts + 1,
    accepts_this_week = accepts_this_week + 1,
    consecutive_declines = 0, -- Reset consecutive declines
    last_accept_at = NOW(),
    
    -- Reduce penalty on acceptance
    decline_penalty = GREATEST(0, decline_penalty - 2.00),
    
    updated_at = NOW()
  WHERE mechanic_id = p_mechanic_id;
  
  -- Update request broadcast
  UPDATE request_broadcasts
  SET
    response_status = 'accepted',
    responded_at = NOW(),
    response_time_seconds = EXTRACT(EPOCH FROM (NOW() - notification_sent_at))::INTEGER
  WHERE request_id = p_request_id 
    AND mechanic_id = p_mechanic_id
    AND response_status = 'pending';
  
  -- Update request queue
  UPDATE service_request_queue
  SET
    is_active = FALSE,
    matched_at = NOW(),
    updated_at = NOW()
  WHERE request_id = p_request_id;
  
  -- Log activity
  INSERT INTO mechanic_activity_logs (
    mechanic_id,
    action_type,
    target_type,
    target_id,
    action_details,
    created_at
  ) VALUES (
    p_mechanic_id,
    'request_accepted',
    'service_request',
    p_request_id,
    jsonb_build_object(
      'accepted_at', NOW()
    ),
    NOW()
  );
  
  v_result := jsonb_build_object(
    'success', TRUE,
    'mechanic_id', p_mechanic_id,
    'message', 'Request accepted successfully'
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Reset Daily Decline Counters
-- Should be run daily via cron job
-- ============================================
CREATE OR REPLACE FUNCTION reset_daily_decline_counters()
RETURNS INTEGER AS $$
DECLARE
  v_updated INTEGER;
BEGIN
  UPDATE mechanic_queue_scores
  SET
    declines_today = 0,
    decline_penalty = GREATEST(0, decline_penalty * 0.5), -- Reduce penalty by 50%
    is_suspended = FALSE,
    suspension_ends_at = NULL,
    suspension_reason = NULL,
    updated_at = NOW()
  WHERE declines_today > 0;
  
  GET DIAGNOSTICS v_updated = ROW_COUNT;
  
  -- Re-enable suspended mechanics
  UPDATE mechanic_availability_status
  SET
    current_status = 'available',
    is_accepting_requests = TRUE,
    estimated_available_at = NULL,
    updated_at = NOW()
  WHERE mechanic_id IN (
    SELECT mechanic_id 
    FROM mechanic_queue_scores 
    WHERE is_suspended = FALSE
  );
  
  RETURN v_updated;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Calculate Mechanic Priority Score
-- Based on: Queue Score + Location + Rating + Specialization
-- ============================================
CREATE OR REPLACE FUNCTION calculate_mechanic_priority_score(
  p_mechanic_id UUID,
  p_request_id UUID,
  p_customer_lat NUMERIC,
  p_customer_lng NUMERIC,
  p_required_specialization TEXT[] DEFAULT NULL
)
RETURNS DECIMAL AS $$
DECLARE
  v_queue_score DECIMAL := 0;
  v_distance_km DECIMAL := 0;
  v_distance_factor DECIMAL := 0;
  v_rating_factor DECIMAL := 0;
  v_specialization_factor DECIMAL := 0;
  v_availability_factor DECIMAL := 0;
  v_final_score DECIMAL := 0;
  
  v_mechanic_lat NUMERIC;
  v_mechanic_lng NUMERIC;
  v_rating NUMERIC;
  v_specializations TEXT[];
  v_is_available BOOLEAN;
  v_is_suspended BOOLEAN;
BEGIN
  -- Get mechanic queue score
  SELECT COALESCE(total_score, 100.00), is_suspended
  INTO v_queue_score, v_is_suspended
  FROM mechanic_queue_scores
  WHERE mechanic_id = p_mechanic_id;
  
  -- If no queue score exists, initialize it
  IF v_queue_score IS NULL THEN
    PERFORM initialize_mechanic_queue_score(p_mechanic_id);
    v_queue_score := 100.00;
  END IF;
  
  -- If suspended, return very low score
  IF v_is_suspended THEN
    RETURN -1000.00;
  END IF;
  
  -- Get mechanic details
  SELECT 
    current_latitude,
    current_longitude,
    COALESCE(rating, 0),
    COALESCE(is_available, FALSE)
  INTO 
    v_mechanic_lat,
    v_mechanic_lng,
    v_rating,
    v_is_available
  FROM user_profiles
  WHERE id = p_mechanic_id;
  
  -- Get specializations from mechanics table
  SELECT specializations
  INTO v_specializations
  FROM mechanics
  WHERE user_id = p_mechanic_id;
  
  -- Calculate distance factor (closer = higher score)
  -- Assuming PostGIS is available for distance calculation
  IF v_mechanic_lat IS NOT NULL AND v_mechanic_lng IS NOT NULL THEN
    v_distance_km := ST_Distance(
      ST_MakePoint(v_mechanic_lng, v_mechanic_lat)::geography,
      ST_MakePoint(p_customer_lng, p_customer_lat)::geography
    ) / 1000.0; -- Convert meters to km
    
    -- Distance scoring: 100 points at 0km, reducing by 5 points per km
    v_distance_factor := GREATEST(0, 100 - (v_distance_km * 5));
  ELSE
    v_distance_factor := 0; -- No location data
  END IF;
  
  -- Calculate rating factor (0-20 points based on rating)
  v_rating_factor := (v_rating / 5.0) * 20;
  
  -- Calculate specialization match factor
  IF p_required_specialization IS NOT NULL AND v_specializations IS NOT NULL THEN
    -- Check if any required specialization matches
    IF v_specializations && p_required_specialization THEN
      v_specialization_factor := 50.00; -- Bonus for matching specialization
    END IF;
  END IF;
  
  -- Calculate availability factor
  IF v_is_available THEN
    SELECT 
      CASE
        WHEN current_status = 'available' THEN 30.00
        WHEN current_status = 'on_break' THEN 10.00
        WHEN current_status = 'busy' THEN -50.00
        ELSE -100.00
      END
    INTO v_availability_factor
    FROM mechanic_availability_status
    WHERE mechanic_id = p_mechanic_id;
    
    IF v_availability_factor IS NULL THEN
      v_availability_factor := 30.00; -- Default available
    END IF;
  ELSE
    v_availability_factor := -100.00; -- Not available
  END IF;
  
  -- Calculate final priority score
  v_final_score := 
    v_queue_score +           -- Base queue score (0-150)
    v_distance_factor +        -- Distance bonus (0-100)
    v_rating_factor +          -- Rating bonus (0-20)
    v_specialization_factor +  -- Specialization bonus (0-50)
    v_availability_factor;     -- Availability bonus (-100 to 30)
  
  RETURN v_final_score;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Get Ranked Mechanics for Request
-- Returns mechanics sorted by priority score
-- ============================================
CREATE OR REPLACE FUNCTION get_ranked_mechanics_for_request(
  p_request_id UUID,
  p_max_distance_km DECIMAL DEFAULT 50.0,
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  mechanic_id UUID,
  mechanic_name TEXT,
  distance_km DECIMAL,
  priority_score DECIMAL,
  queue_score DECIMAL,
  rating NUMERIC,
  specializations TEXT[],
  is_available BOOLEAN,
  phone_number VARCHAR,
  profile_image_url TEXT
) AS $$
DECLARE
  v_customer_lat NUMERIC;
  v_customer_lng NUMERIC;
  v_required_specializations TEXT[];
BEGIN
  -- Get request details
  SELECT 
    pickup_latitude,
    pickup_longitude
  INTO 
    v_customer_lat,
    v_customer_lng
  FROM service_requests
  WHERE id = p_request_id;
  
  -- Get required specializations from request queue if exists
  SELECT required_skills::jsonb #>> '{}'
  INTO v_required_specializations
  FROM service_request_queue
  WHERE request_id = p_request_id;
  
  -- Return ranked mechanics
  RETURN QUERY
  SELECT 
    up.id AS mechanic_id,
    (up.first_name || ' ' || up.last_name) AS mechanic_name,
    ROUND(
      ST_Distance(
        ST_MakePoint(up.current_longitude, up.current_latitude)::geography,
        ST_MakePoint(v_customer_lng, v_customer_lat)::geography
      ) / 1000.0, 
      2
    ) AS distance_km,
    calculate_mechanic_priority_score(
      up.id,
      p_request_id,
      v_customer_lat,
      v_customer_lng,
      v_required_specializations
    ) AS priority_score,
    COALESCE(mqs.total_score, 100.00) AS queue_score,
    up.rating,
    m.specializations,
    up.is_available,
    up.phone_number,
    up.profile_image_url
  FROM user_profiles up
  INNER JOIN mechanics m ON m.user_id = up.id
  LEFT JOIN mechanic_queue_scores mqs ON mqs.mechanic_id = up.id
  WHERE 
    up.user_type = 'mechanic'
    AND up.status = 'active'
    AND up.current_latitude IS NOT NULL
    AND up.current_longitude IS NOT NULL
    AND ST_DWithin(
      ST_MakePoint(up.current_longitude, up.current_latitude)::geography,
      ST_MakePoint(v_customer_lng, v_customer_lat)::geography,
      p_max_distance_km * 1000 -- Convert km to meters
    )
    AND COALESCE(mqs.is_suspended, FALSE) = FALSE
  ORDER BY priority_score DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- TRIGGER: Update mechanic queue score on rating change
-- ============================================
CREATE OR REPLACE FUNCTION update_queue_score_on_rating_change()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.rating IS DISTINCT FROM OLD.rating AND NEW.user_type = 'mechanic' THEN
    UPDATE mechanic_queue_scores
    SET
      rating_bonus = CASE
        WHEN NEW.rating >= 4.5 THEN 20.00
        WHEN NEW.rating >= 4.0 THEN 10.00
        WHEN NEW.rating >= 3.5 THEN 5.00
        ELSE 0.00
      END,
      updated_at = NOW()
    WHERE mechanic_id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_queue_score_on_rating
AFTER UPDATE ON user_profiles
FOR EACH ROW
EXECUTE FUNCTION update_queue_score_on_rating_change();

-- ============================================
-- TRIGGER: Auto-remove suspension when time expires
-- ============================================
CREATE OR REPLACE FUNCTION auto_remove_expired_suspensions()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_suspended = TRUE 
     AND NEW.suspension_ends_at IS NOT NULL 
     AND NEW.suspension_ends_at <= NOW() THEN
    
    NEW.is_suspended := FALSE;
    NEW.suspension_ends_at := NULL;
    NEW.suspension_reason := NULL;
    NEW.updated_at := NOW();
    
    -- Re-enable mechanic
    UPDATE mechanic_availability_status
    SET
      current_status = 'available',
      is_accepting_requests = TRUE,
      updated_at = NOW()
    WHERE mechanic_id = NEW.mechanic_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_remove_suspensions
BEFORE UPDATE ON mechanic_queue_scores
FOR EACH ROW
EXECUTE FUNCTION auto_remove_expired_suspensions();

-- ============================================
-- GRANT PERMISSIONS
-- ============================================
GRANT SELECT, INSERT, UPDATE ON mechanic_queue_scores TO authenticated;
GRANT SELECT ON service_request_queue TO authenticated;
GRANT EXECUTE ON FUNCTION handle_mechanic_decline TO authenticated;
GRANT EXECUTE ON FUNCTION handle_mechanic_accept TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_mechanic_priority_score TO authenticated;
GRANT EXECUTE ON FUNCTION get_ranked_mechanics_for_request TO authenticated;

-- ============================================
-- COMMENTS
-- ============================================
COMMENT ON TABLE mechanic_queue_scores IS 'Tracks mechanic queue priority scores with decline penalties and bonuses';
COMMENT ON TABLE service_request_queue IS 'Enhanced queue management for service requests with priority scoring';
COMMENT ON FUNCTION handle_mechanic_decline IS 'Handles mechanic decline with progressive penalties and suspension logic';
COMMENT ON FUNCTION handle_mechanic_accept IS 'Handles mechanic acceptance and rewards positive behavior';
COMMENT ON FUNCTION calculate_mechanic_priority_score IS 'Calculates comprehensive priority score based on multiple factors';
COMMENT ON FUNCTION get_ranked_mechanics_for_request IS 'Returns ranked list of mechanics for a specific request';
