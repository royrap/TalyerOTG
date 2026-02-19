-- ============================================
-- RPC FUNCTIONS FOR CLIENT APPLICATIONS
-- Callable from Flutter/TypeScript via Supabase
-- ============================================

-- ============================================
-- RPC: Mechanic Declines Request
-- ============================================
CREATE OR REPLACE FUNCTION rpc_mechanic_decline_request(
  p_mechanic_id UUID,
  p_request_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_result JSONB;
BEGIN
  -- Verify mechanic owns this ID (security check)
  IF auth.uid() != p_mechanic_id THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Unauthorized'
    );
  END IF;
  
  -- Handle the decline
  v_result := handle_mechanic_decline(p_mechanic_id, p_request_id, p_reason);
  
  -- If too many declines today, notify mechanic
  IF (v_result->>'is_suspended')::BOOLEAN = TRUE THEN
    -- Insert notification
    INSERT INTO notifications (
      user_id,
      title,
      body,
      type,
      data
    ) VALUES (
      p_mechanic_id,
      'Account Temporarily Suspended',
      'You have declined too many requests today. You can resume receiving requests in 1 hour.',
      'suspension',
      jsonb_build_object(
        'suspension_ends_at', NOW() + INTERVAL '1 hour',
        'reason', 'excessive_declines'
      )
    );
  END IF;
  
  RETURN v_result;
END;
$$;

-- ============================================
-- RPC: Mechanic Accepts Request
-- ============================================
CREATE OR REPLACE FUNCTION rpc_mechanic_accept_request(
  p_mechanic_id UUID,
  p_request_id UUID
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_result JSONB;
  v_customer_id UUID;
BEGIN
  -- Verify mechanic owns this ID
  IF auth.uid() != p_mechanic_id THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Unauthorized'
    );
  END IF;
  
  -- Check if request is still available
  IF NOT EXISTS (
    SELECT 1 FROM service_requests
    WHERE id = p_request_id
      AND status IN ('pending', 'assigned')
      AND (assigned_mechanic_id IS NULL OR assigned_mechanic_id = p_mechanic_id)
  ) THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Request is no longer available'
    );
  END IF;
  
  -- Handle the acceptance
  v_result := handle_mechanic_accept(p_mechanic_id, p_request_id);
  
  -- Update request with mechanic
  UPDATE service_requests
  SET
    assigned_mechanic_id = p_mechanic_id,
    status = 'accepted',
    accepted_at = NOW(),
    first_response_at = COALESCE(first_response_at, NOW()),
    updated_at = NOW()
  WHERE id = p_request_id
  RETURNING customer_id INTO v_customer_id;
  
  -- Update mechanic status
  UPDATE mechanic_availability_status
  SET
    current_status = 'in_service',
    current_request_id = p_request_id,
    updated_at = NOW()
  WHERE mechanic_id = p_mechanic_id;
  
  -- Notify customer
  INSERT INTO notifications (
    user_id,
    title,
    body,
    type,
    data
  ) VALUES (
    v_customer_id,
    'Mechanic Accepted Your Request',
    'A mechanic is on the way!',
    'request_accepted',
    jsonb_build_object(
      'request_id', p_request_id,
      'mechanic_id', p_mechanic_id
    )
  );
  
  -- Cancel other pending broadcasts
  UPDATE request_broadcasts
  SET
    response_status = 'expired',
    updated_at = NOW()
  WHERE request_id = p_request_id
    AND mechanic_id != p_mechanic_id
    AND response_status = 'pending';
  
  RETURN v_result;
END;
$$;

-- ============================================
-- RPC: Customer Creates Request (Auto-match)
-- ============================================
CREATE OR REPLACE FUNCTION rpc_customer_create_request_with_matching(
  p_customer_id UUID,
  p_title TEXT,
  p_description TEXT,
  p_category_id UUID,
  p_latitude NUMERIC,
  p_longitude NUMERIC,
  p_urgency_level TEXT DEFAULT 'normal'
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_request_id UUID;
  v_match_result JSONB;
BEGIN
  -- Verify customer owns this ID
  IF auth.uid() != p_customer_id THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Unauthorized'
    );
  END IF;
  
  -- Create service request
  INSERT INTO service_requests (
    customer_id,
    category_id,
    title,
    description,
    pickup_latitude,
    pickup_longitude,
    status,
    is_emergency
  ) VALUES (
    p_customer_id,
    p_category_id,
    p_title,
    p_description,
    p_latitude,
    p_longitude,
    'pending',
    p_urgency_level = 'emergency'
  )
  RETURNING id INTO v_request_id;
  
  -- Create queue entry
  PERFORM create_service_request_queue_entry(
    v_request_id,
    p_category_id,
    p_urgency_level,
    50.0
  );
  
  -- Auto-match to best mechanic
  v_match_result := auto_match_request_to_mechanic(v_request_id);
  
  RETURN jsonb_build_object(
    'success', TRUE,
    'request_id', v_request_id,
    'matching_result', v_match_result
  );
END;
$$;

-- ============================================
-- RPC: Get Available Mechanics Near Location
-- ============================================
CREATE OR REPLACE FUNCTION rpc_get_nearby_mechanics(
  p_latitude NUMERIC,
  p_longitude NUMERIC,
  p_max_distance_km DECIMAL DEFAULT 50.0,
  p_specialization TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 20
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
  profile_image_url TEXT,
  current_status TEXT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    up.id AS mechanic_id,
    (up.first_name || ' ' || up.last_name) AS mechanic_name,
    ROUND(
      ST_Distance(
        ST_MakePoint(up.current_longitude, up.current_latitude)::geography,
        ST_MakePoint(p_longitude, p_latitude)::geography
      ) / 1000.0, 
      2
    ) AS distance_km,
    COALESCE(mqs.total_score, 100.00) +
      GREATEST(0, 100 - (
        ST_Distance(
          ST_MakePoint(up.current_longitude, up.current_latitude)::geography,
          ST_MakePoint(p_longitude, p_latitude)::geography
        ) / 1000.0 * 5
      )) AS priority_score,
    COALESCE(mqs.total_score, 100.00) AS queue_score,
    up.rating,
    m.specializations,
    COALESCE(mas.is_accepting_requests, FALSE) AS is_available,
    up.phone_number,
    up.profile_image_url,
    COALESCE(mas.current_status, 'offline') AS current_status
  FROM user_profiles up
  INNER JOIN mechanics m ON m.user_id = up.id
  LEFT JOIN mechanic_queue_scores mqs ON mqs.mechanic_id = up.id
  LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
  WHERE 
    up.user_type = 'mechanic'
    AND up.status = 'active'
    AND up.current_latitude IS NOT NULL
    AND up.current_longitude IS NOT NULL
    AND COALESCE(mqs.is_suspended, FALSE) = FALSE
    AND ST_DWithin(
      ST_MakePoint(up.current_longitude, up.current_latitude)::geography,
      ST_MakePoint(p_longitude, p_latitude)::geography,
      p_max_distance_km * 1000
    )
    AND (
      p_specialization IS NULL 
      OR m.specializations && ARRAY[p_specialization]::TEXT[]
    )
  ORDER BY priority_score DESC
  LIMIT p_limit;
END;
$$;

-- ============================================
-- RPC: Get Mechanic Queue Dashboard
-- ============================================
CREATE OR REPLACE FUNCTION rpc_get_my_queue_dashboard(
  p_mechanic_id UUID
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Verify mechanic owns this ID
  IF auth.uid() != p_mechanic_id THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Unauthorized'
    );
  END IF;
  
  RETURN get_mechanic_queue_dashboard(p_mechanic_id);
END;
$$;

-- ============================================
-- RPC: Get Pending Requests for Mechanic
-- ============================================
CREATE OR REPLACE FUNCTION rpc_get_my_pending_requests(
  p_mechanic_id UUID
)
RETURNS TABLE (
  request_id UUID,
  customer_name TEXT,
  service_title TEXT,
  distance_km DECIMAL,
  urgency_level TEXT,
  estimated_price NUMERIC,
  created_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  time_remaining_minutes INTEGER
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Verify mechanic owns this ID
  IF auth.uid() != p_mechanic_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  
  RETURN QUERY
  SELECT 
    sr.id AS request_id,
    (up.first_name || ' ' || up.last_name) AS customer_name,
    sr.title AS service_title,
    rb.distance_km,
    COALESCE(srq.urgency_level, 'normal') AS urgency_level,
    sr.estimated_price,
    sr.created_at,
    srq.expires_at,
    EXTRACT(EPOCH FROM (srq.expires_at - NOW()))::INTEGER / 60 AS time_remaining_minutes
  FROM request_broadcasts rb
  INNER JOIN service_requests sr ON sr.id = rb.request_id
  INNER JOIN user_profiles up ON up.id = sr.customer_id
  LEFT JOIN service_request_queue srq ON srq.request_id = sr.id
  WHERE 
    rb.mechanic_id = p_mechanic_id
    AND rb.response_status = 'pending'
    AND sr.status IN ('pending', 'assigned')
    AND srq.expires_at > NOW()
  ORDER BY 
    CASE srq.urgency_level
      WHEN 'emergency' THEN 1
      WHEN 'high' THEN 2
      WHEN 'normal' THEN 3
      WHEN 'low' THEN 4
    END,
    sr.created_at ASC;
END;
$$;

-- ============================================
-- RPC: Admin - Get Queue Statistics
-- ============================================
CREATE OR REPLACE FUNCTION rpc_admin_get_queue_stats()
RETURNS TABLE (
  active_requests INTEGER,
  pending_broadcasts INTEGER,
  average_wait_time_minutes DECIMAL,
  total_mechanics_available INTEGER,
  total_mechanics_suspended INTEGER,
  average_queue_score DECIMAL,
  top_performers JSONB,
  bottom_performers JSONB
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_is_admin BOOLEAN;
BEGIN
  -- Check if user is admin
  SELECT 
    user_type IN ('admin', 'super_admin')
  INTO v_is_admin
  FROM user_profiles
  WHERE id = auth.uid();
  
  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Unauthorized - Admin access required';
  END IF;
  
  RETURN QUERY
  SELECT 
    qs.*,
    (
      SELECT jsonb_agg(row_to_json(t))
      FROM (
        SELECT 
          up.id,
          up.first_name || ' ' || up.last_name AS name,
          mqs.total_score,
          mqs.total_accepts,
          up.rating
        FROM mechanic_queue_scores mqs
        INNER JOIN user_profiles up ON up.id = mqs.mechanic_id
        ORDER BY mqs.total_score DESC
        LIMIT 5
      ) t
    ) AS top_performers,
    (
      SELECT jsonb_agg(row_to_json(t))
      FROM (
        SELECT 
          up.id,
          up.first_name || ' ' || up.last_name AS name,
          mqs.total_score,
          mqs.declines_today,
          mqs.is_suspended
        FROM mechanic_queue_scores mqs
        INNER JOIN user_profiles up ON up.id = mqs.mechanic_id
        WHERE mqs.declines_today > 0
        ORDER BY mqs.total_score ASC
        LIMIT 5
      ) t
    ) AS bottom_performers
  FROM get_queue_statistics() qs;
END;
$$;

-- ============================================
-- RPC: Reset My Decline Count (Mechanic Petition)
-- Admins can manually reset a mechanic's decline count
-- ============================================
CREATE OR REPLACE FUNCTION rpc_admin_reset_mechanic_declines(
  p_admin_id UUID,
  p_mechanic_id UUID,
  p_reason TEXT
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_is_admin BOOLEAN;
BEGIN
  -- Check if user is admin
  SELECT 
    user_type IN ('admin', 'super_admin')
  INTO v_is_admin
  FROM user_profiles
  WHERE id = p_admin_id;
  
  IF NOT v_is_admin THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Unauthorized - Admin access required'
    );
  END IF;
  
  -- Reset mechanic's decline count
  UPDATE mechanic_queue_scores
  SET
    declines_today = 0,
    declines_this_week = GREATEST(0, declines_this_week - 5),
    consecutive_declines = 0,
    decline_penalty = 0.00,
    is_suspended = FALSE,
    suspension_ends_at = NULL,
    suspension_reason = NULL,
    updated_at = NOW()
  WHERE mechanic_id = p_mechanic_id;
  
  -- Re-enable mechanic
  UPDATE mechanic_availability_status
  SET
    current_status = 'available',
    is_accepting_requests = TRUE,
    updated_at = NOW()
  WHERE mechanic_id = p_mechanic_id;
  
  -- Log admin action
  INSERT INTO admin_activity_logs (
    admin_id,
    action_type,
    target_type,
    target_id,
    action_details
  ) VALUES (
    p_admin_id,
    'reset_decline_count',
    'mechanic',
    p_mechanic_id,
    jsonb_build_object(
      'reason', p_reason,
      'timestamp', NOW()
    )
  );
  
  RETURN jsonb_build_object(
    'success', TRUE,
    'message', 'Mechanic decline count has been reset'
  );
END;
$$;

-- ============================================
-- GRANT PERMISSIONS
-- ============================================
GRANT EXECUTE ON FUNCTION rpc_mechanic_decline_request TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_mechanic_accept_request TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_customer_create_request_with_matching TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_get_nearby_mechanics TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_get_my_queue_dashboard TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_get_my_pending_requests TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_admin_get_queue_stats TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_admin_reset_mechanic_declines TO authenticated;

-- ============================================
-- COMMENTS
-- ============================================
COMMENT ON FUNCTION rpc_mechanic_decline_request IS 'Mechanic declines a service request with automatic penalty tracking';
COMMENT ON FUNCTION rpc_mechanic_accept_request IS 'Mechanic accepts a service request and updates queue score positively';
COMMENT ON FUNCTION rpc_customer_create_request_with_matching IS 'Creates a service request and automatically matches with best mechanic';
COMMENT ON FUNCTION rpc_get_nearby_mechanics IS 'Gets list of available mechanics near a location sorted by priority';
COMMENT ON FUNCTION rpc_get_my_queue_dashboard IS 'Returns mechanic queue dashboard with scores and statistics';
COMMENT ON FUNCTION rpc_get_my_pending_requests IS 'Gets all pending service requests assigned to a mechanic';
COMMENT ON FUNCTION rpc_admin_get_queue_stats IS 'Admin function to view queue statistics and performance metrics';
COMMENT ON FUNCTION rpc_admin_reset_mechanic_declines IS 'Admin function to manually reset mechanic decline penalties';
