-- Photo Progress System Database Setup
-- This creates tables and functions for tracking service progress with photos

-- 1. Create progress_photos table
CREATE TABLE IF NOT EXISTS progress_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_request_id UUID NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
    mechanic_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    service_phase TEXT NOT NULL CHECK (service_phase IN (
        'arrival', 'inspection', 'diagnosis', 'work_in_progress', 'testing', 'completion'
    )),
    image_url TEXT NOT NULL,
    description TEXT DEFAULT '',
    timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB DEFAULT '{}',
    
    -- Indexes for performance
    CONSTRAINT progress_photos_service_request_id_idx 
        FOREIGN KEY (service_request_id) REFERENCES service_requests(id),
    CONSTRAINT progress_photos_mechanic_id_idx 
        FOREIGN KEY (mechanic_id) REFERENCES user_profiles(id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_progress_photos_service_request 
ON progress_photos(service_request_id, timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_progress_photos_mechanic 
ON progress_photos(mechanic_id, timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_progress_photos_phase 
ON progress_photos(service_phase, timestamp DESC);

-- 2. Create service_phase_tracking table for current phase tracking
CREATE TABLE IF NOT EXISTS service_phase_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_request_id UUID NOT NULL UNIQUE REFERENCES service_requests(id) ON DELETE CASCADE,
    current_phase TEXT NOT NULL DEFAULT 'arrival' CHECK (current_phase IN (
        'arrival', 'inspection', 'diagnosis', 'work_in_progress', 'testing', 'completion'
    )),
    phase_started_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    mechanic_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    
    -- Track phase history
    phase_history JSONB DEFAULT '[]'::jsonb
);

-- Create unique index
CREATE UNIQUE INDEX IF NOT EXISTS idx_service_phase_tracking_service_request 
ON service_phase_tracking(service_request_id);

-- 3. Function to get current service phase
CREATE OR REPLACE FUNCTION get_current_service_phase(request_id UUID)
RETURNS TABLE (
    phase TEXT,
    started_at TIMESTAMPTZ,
    mechanic_id UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        spt.current_phase,
        spt.phase_started_at,
        spt.mechanic_id
    FROM service_phase_tracking spt
    WHERE spt.service_request_id = request_id;
END;
$$ LANGUAGE plpgsql;

-- 4. Function to update service phase
CREATE OR REPLACE FUNCTION update_service_phase(
    request_id UUID,
    new_phase TEXT,
    mech_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    old_phase TEXT;
    phase_exists BOOLEAN;
BEGIN
    -- Check if phase tracking exists
    SELECT EXISTS(
        SELECT 1 FROM service_phase_tracking 
        WHERE service_request_id = request_id
    ) INTO phase_exists;
    
    -- Get current phase for history
    IF phase_exists THEN
        SELECT current_phase INTO old_phase
        FROM service_phase_tracking 
        WHERE service_request_id = request_id;
    END IF;
    
    -- Insert or update phase tracking
    INSERT INTO service_phase_tracking (
        service_request_id, 
        current_phase, 
        phase_started_at,
        mechanic_id,
        phase_history
    ) VALUES (
        request_id,
        new_phase,
        CURRENT_TIMESTAMP,
        mech_id,
        CASE WHEN phase_exists THEN 
            (SELECT phase_history FROM service_phase_tracking WHERE service_request_id = request_id) ||
            jsonb_build_object(
                'phase', old_phase,
                'ended_at', CURRENT_TIMESTAMP
            )
        ELSE '[]'::jsonb END
    )
    ON CONFLICT (service_request_id) DO UPDATE SET
        current_phase = EXCLUDED.current_phase,
        phase_started_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP,
        mechanic_id = COALESCE(EXCLUDED.mechanic_id, service_phase_tracking.mechanic_id),
        phase_history = service_phase_tracking.phase_history ||
            jsonb_build_object(
                'phase', service_phase_tracking.current_phase,
                'ended_at', CURRENT_TIMESTAMP
            );
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 5. Function to get progress photos for a service request
CREATE OR REPLACE FUNCTION get_service_progress_photos(request_id UUID)
RETURNS TABLE (
    id UUID,
    service_phase TEXT,
    image_url TEXT,
    description TEXT,
    photo_timestamp TIMESTAMPTZ,
    mechanic_id UUID,
    metadata JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pp.id,
        pp.service_phase,
        pp.image_url,
        pp.description,
        pp.timestamp as photo_timestamp,
        pp.mechanic_id,
        pp.metadata
    FROM progress_photos pp
    WHERE pp.service_request_id = request_id
    ORDER BY pp.timestamp DESC;
END;
$$ LANGUAGE plpgsql;

-- 6. Function to add progress photo
CREATE OR REPLACE FUNCTION add_progress_photo(
    request_id UUID,
    mech_id UUID,
    phase TEXT,
    img_url TEXT,
    photo_description TEXT DEFAULT '',
    photo_metadata JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    photo_id UUID;
BEGIN
    -- Insert the photo
    INSERT INTO progress_photos (
        service_request_id,
        mechanic_id,
        service_phase,
        image_url,
        description,
        metadata
    ) VALUES (
        request_id,
        mech_id,
        phase,
        img_url,
        photo_description,
        photo_metadata
    ) RETURNING id INTO photo_id;
    
    -- Update the current service phase
    PERFORM update_service_phase(request_id, phase, mech_id);
    
    RETURN photo_id;
END;
$$ LANGUAGE plpgsql;

-- 7. Function to get progress statistics
CREATE OR REPLACE FUNCTION get_progress_statistics(request_id UUID)
RETURNS TABLE (
    total_photos INTEGER,
    phases_completed INTEGER,
    current_phase TEXT,
    started_at TIMESTAMPTZ,
    last_update TIMESTAMPTZ,
    completion_percentage NUMERIC
) AS $$
DECLARE
    total_phases INTEGER := 6; -- arrival, inspection, diagnosis, work_in_progress, testing, completion
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(pp_stats.photo_count, 0)::INTEGER as total_photos,
        COALESCE(pp_stats.unique_phases, 0)::INTEGER as phases_completed,
        COALESCE(spt.current_phase, 'arrival')::TEXT as current_phase,
        COALESCE(spt.phase_started_at, CURRENT_TIMESTAMP)::TIMESTAMPTZ as started_at,
        COALESCE(pp_stats.last_photo, spt.updated_at, CURRENT_TIMESTAMP)::TIMESTAMPTZ as last_update,
        ROUND((COALESCE(pp_stats.unique_phases, 0)::NUMERIC / total_phases::NUMERIC) * 100, 1) as completion_percentage
    FROM service_phase_tracking spt
    LEFT JOIN (
        SELECT 
            COUNT(*) as photo_count,
            COUNT(DISTINCT service_phase) as unique_phases,
            MAX(timestamp) as last_photo
        FROM progress_photos 
        WHERE service_request_id = request_id
    ) pp_stats ON true
    WHERE spt.service_request_id = request_id;
END;
$$ LANGUAGE plpgsql;

-- 8. Function to get mechanic progress summary
CREATE OR REPLACE FUNCTION get_mechanic_progress_summary(mech_id UUID)
RETURNS TABLE (
    service_request_id UUID,
    current_phase TEXT,
    photo_count INTEGER,
    last_update TIMESTAMPTZ,
    completion_percentage NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        spt.service_request_id,
        spt.current_phase,
        COALESCE(pp_count.photo_count, 0)::INTEGER,
        GREATEST(spt.updated_at, COALESCE(pp_count.last_photo, spt.updated_at)) as last_update,
        CASE 
            WHEN spt.current_phase = 'completion' THEN 100.0
            WHEN spt.current_phase = 'testing' THEN 83.3
            WHEN spt.current_phase = 'work_in_progress' THEN 66.7
            WHEN spt.current_phase = 'diagnosis' THEN 50.0
            WHEN spt.current_phase = 'inspection' THEN 33.3
            WHEN spt.current_phase = 'arrival' THEN 16.7
            ELSE 0.0
        END as completion_percentage
    FROM service_phase_tracking spt
    LEFT JOIN (
        SELECT 
            service_request_id,
            COUNT(*) as photo_count,
            MAX(timestamp) as last_photo
        FROM progress_photos 
        WHERE mechanic_id = mech_id
        GROUP BY service_request_id
    ) pp_count ON spt.service_request_id = pp_count.service_request_id
    WHERE spt.mechanic_id = mech_id
    ORDER BY last_update DESC;
END;
$$ LANGUAGE plpgsql;

-- 9. Enable Row Level Security (RLS)
ALTER TABLE progress_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_phase_tracking ENABLE ROW LEVEL SECURITY;

-- 10. Create RLS policies

-- Progress photos policies
CREATE POLICY "Mechanics can insert their own progress photos" 
ON progress_photos FOR INSERT 
WITH CHECK (mechanic_id = auth.uid());

CREATE POLICY "Mechanics can view their own progress photos" 
ON progress_photos FOR SELECT 
USING (mechanic_id = auth.uid());

CREATE POLICY "Customers can view progress photos for their requests" 
ON progress_photos FOR SELECT 
USING (
    service_request_id IN (
        SELECT id FROM service_requests 
        WHERE customer_id = auth.uid()
    )
);

-- Service phase tracking policies
CREATE POLICY "Mechanics can update phase tracking for their jobs" 
ON service_phase_tracking FOR ALL 
USING (mechanic_id = auth.uid())
WITH CHECK (mechanic_id = auth.uid());

CREATE POLICY "Customers can view phase tracking for their requests" 
ON service_phase_tracking FOR SELECT 
USING (
    service_request_id IN (
        SELECT id FROM service_requests 
        WHERE customer_id = auth.uid()
    )
);

-- 11. Create notification trigger for new progress photos
CREATE OR REPLACE FUNCTION notify_progress_photo_added()
RETURNS TRIGGER AS $$
DECLARE
    customer_id UUID;
    customer_fcm_token TEXT;
    service_type TEXT;
BEGIN
    -- Get customer info
    SELECT sr.customer_id, up.notification_preferences->>'fcm_token', sr.service_type
    INTO customer_id, customer_fcm_token, service_type
    FROM service_requests sr
    JOIN user_profiles up ON sr.customer_id = up.id
    WHERE sr.id = NEW.service_request_id;
    
    -- Insert notification for customer
    INSERT INTO notifications (
        user_id,
        title,
        body,
        type,
        data
    ) VALUES (
        customer_id,
        'Service Progress Update',
        format('Your mechanic shared a new photo for %s - %s', service_type, NEW.service_phase),
        'progress_photo',
        jsonb_build_object(
            'service_request_id', NEW.service_request_id,
            'photo_id', NEW.id,
            'service_phase', NEW.service_phase,
            'image_url', NEW.image_url
        )
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
DROP TRIGGER IF EXISTS trigger_progress_photo_notification ON progress_photos;
CREATE TRIGGER trigger_progress_photo_notification
    AFTER INSERT ON progress_photos
    FOR EACH ROW
    EXECUTE FUNCTION notify_progress_photo_added();

-- 12. Add helpful indexes for real-time queries
CREATE INDEX IF NOT EXISTS idx_progress_photos_realtime 
ON progress_photos(service_request_id, timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_service_phase_tracking_active 
ON service_phase_tracking(mechanic_id, updated_at DESC) 
WHERE current_phase != 'completion';

-- 13. Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON progress_photos TO authenticated;
GRANT SELECT, INSERT, UPDATE ON service_phase_tracking TO authenticated;
GRANT EXECUTE ON FUNCTION get_current_service_phase(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION update_service_phase(UUID, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_service_progress_photos(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION add_progress_photo(UUID, UUID, TEXT, TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION get_progress_statistics(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_mechanic_progress_summary(UUID) TO authenticated;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Photo Progress System database setup completed successfully!';
    RAISE NOTICE '📊 Created tables: progress_photos, service_phase_tracking';
    RAISE NOTICE '🔧 Created functions: get_current_service_phase, update_service_phase, add_progress_photo, etc.';
    RAISE NOTICE '🔒 RLS policies enabled for data security';
    RAISE NOTICE '🔔 Real-time notifications configured';
END $$;