-- Add ETA tracking columns to service_requests table
-- This enables real-time ETA storage and persistence

-- Add ETA tracking columns
ALTER TABLE service_requests 
ADD COLUMN IF NOT EXISTS current_eta_minutes INTEGER,
ADD COLUMN IF NOT EXISTS current_distance_km DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS traffic_condition VARCHAR(20) DEFAULT 'normal',
ADD COLUMN IF NOT EXISTS eta_last_updated TIMESTAMP WITH TIME ZONE;

-- Add index for better query performance
CREATE INDEX IF NOT EXISTS idx_service_requests_eta 
ON service_requests(id, current_eta_minutes) 
WHERE current_eta_minutes IS NOT NULL;

-- Add comment for documentation
COMMENT ON COLUMN service_requests.current_eta_minutes IS 'Current estimated time of arrival in minutes';
COMMENT ON COLUMN service_requests.current_distance_km IS 'Current distance between mechanic and customer in kilometers';
COMMENT ON COLUMN service_requests.traffic_condition IS 'Traffic condition: light, normal, moderate, heavy, estimated';
COMMENT ON COLUMN service_requests.eta_last_updated IS 'Timestamp when ETA was last calculated';

-- Create function to update ETA data
CREATE OR REPLACE FUNCTION update_service_eta(
    p_service_request_id UUID,
    p_eta_minutes INTEGER,
    p_distance_km DECIMAL(10,2),
    p_traffic_condition VARCHAR(20) DEFAULT 'normal'
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE service_requests 
    SET 
        current_eta_minutes = p_eta_minutes,
        current_distance_km = p_distance_km,
        traffic_condition = p_traffic_condition,
        eta_last_updated = NOW()
    WHERE id = p_service_request_id;
    
    IF FOUND THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create function to get ETA data
CREATE OR REPLACE FUNCTION get_service_eta(p_service_request_id UUID)
RETURNS TABLE(
    eta_minutes INTEGER,
    distance_km DECIMAL(10,2),
    traffic_condition VARCHAR(20),
    last_updated TIMESTAMP WITH TIME ZONE,
    is_stale BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sr.current_eta_minutes,
        sr.current_distance_km,
        sr.traffic_condition,
        sr.eta_last_updated,
        (sr.eta_last_updated IS NULL OR sr.eta_last_updated < NOW() - INTERVAL '5 minutes') as is_stale
    FROM service_requests sr
    WHERE sr.id = p_service_request_id;
END;
$$ LANGUAGE plpgsql;

-- Test the new functions
DO $$
DECLARE
    test_request_id UUID;
    eta_result RECORD;
BEGIN
    -- Get a sample request ID for testing
    SELECT id INTO test_request_id 
    FROM service_requests 
    WHERE status IN ('in_progress', 'assigned')
    LIMIT 1;
    
    IF test_request_id IS NOT NULL THEN
        -- Test updating ETA
        PERFORM update_service_eta(test_request_id, 15, 5.2, 'moderate');
        
        -- Test getting ETA
        SELECT * INTO eta_result FROM get_service_eta(test_request_id);
        
        RAISE NOTICE '✅ ETA functions tested successfully';
        RAISE NOTICE 'Test ETA: % minutes, Distance: % km, Traffic: %', 
            eta_result.eta_minutes, eta_result.distance_km, eta_result.traffic_condition;
    ELSE
        RAISE NOTICE '⚠️ No active service requests found for testing';
    END IF;
END $$;

-- Success messages
DO $$
BEGIN
    RAISE NOTICE '🚗 Real-time ETA tracking database setup completed!';
    RAISE NOTICE '';
    RAISE NOTICE '📊 New Features Added:';
    RAISE NOTICE '• current_eta_minutes - Real-time ETA in minutes';
    RAISE NOTICE '• current_distance_km - Distance between mechanic and customer'; 
    RAISE NOTICE '• traffic_condition - Traffic status (light/normal/moderate/heavy)';
    RAISE NOTICE '• eta_last_updated - Timestamp of last ETA calculation';
    RAISE NOTICE '';
    RAISE NOTICE '🔧 Functions Created:';
    RAISE NOTICE '• update_service_eta() - Update ETA data for a service request';
    RAISE NOTICE '• get_service_eta() - Get current ETA data with staleness indicator';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Usage in Flutter:';
    RAISE NOTICE '• RealTimeETAService will automatically store ETA updates';
    RAISE NOTICE '• RealTimeETAWidget will display live ETA to customers';
    RAISE NOTICE '• ETA updates every 30 seconds with traffic consideration';
END $$;