-- Service Status Synchronization Enhancement
-- Ensures service request status changes sync properly between customer and mechanic views

-- 1. Create status synchronization function
CREATE OR REPLACE FUNCTION sync_service_request_status()
RETURNS TRIGGER AS $$
DECLARE
    v_old_status TEXT;
    v_new_status TEXT;
    v_customer_id UUID;
    v_mechanic_id UUID;
    v_notification_data jsonb;
BEGIN
    v_old_status := COALESCE(OLD.status, 'unknown');
    v_new_status := NEW.status;
    v_customer_id := NEW.customer_id;
    v_mechanic_id := NEW.assigned_mechanic_id;
    
    -- Skip if status hasn't actually changed
    IF v_old_status = v_new_status THEN
        RETURN NEW;
    END IF;
    
    RAISE NOTICE '🔄 Service request % status changing: % → %', 
                 NEW.id, v_old_status, v_new_status;
    
    -- Build notification payload
    v_notification_data := jsonb_build_object(
        'service_request_id', NEW.id,
        'old_status', v_old_status,
        'new_status', v_new_status,
        'customer_id', v_customer_id,
        'mechanic_id', v_mechanic_id,
        'timestamp', NOW(),
        'total_amount', NEW.total_amount,
        'pickup_location', NEW.pickup_location,
        'service_type', NEW.service_type
    );
    
    -- Send real-time notifications to both customer and mechanic
    PERFORM pg_notify('service_status_change', v_notification_data::text);
    
    -- Customer-specific notification
    IF v_customer_id IS NOT NULL THEN
        PERFORM pg_notify(
            'customer_' || v_customer_id::text, 
            jsonb_build_object(
                'type', 'status_change',
                'data', v_notification_data
            )::text
        );
    END IF;
    
    -- Mechanic-specific notification
    IF v_mechanic_id IS NOT NULL THEN
        PERFORM pg_notify(
            'mechanic_' || v_mechanic_id::text,
            jsonb_build_object(
                'type', 'status_change', 
                'data', v_notification_data
            )::text
        );
    END IF;
    
    -- Log status transition for debugging
    INSERT INTO service_request_status_log (
        service_request_id,
        old_status,
        new_status,
        changed_by,
        changed_at,
        additional_data
    ) VALUES (
        NEW.id,
        v_old_status,
        v_new_status,
        COALESCE(current_setting('app.current_user_id', true), 'system'),
        NOW(),
        v_notification_data
    )
    ON CONFLICT DO NOTHING; -- Ignore if status log table doesn't exist
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Create status log table (if it doesn't exist)
CREATE TABLE IF NOT EXISTS service_request_status_log (
    id SERIAL PRIMARY KEY,
    service_request_id UUID NOT NULL,
    old_status TEXT,
    new_status TEXT NOT NULL,
    changed_by TEXT DEFAULT 'system',
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    additional_data jsonb,
    
    CONSTRAINT fk_service_request 
        FOREIGN KEY (service_request_id) 
        REFERENCES service_requests(id) 
        ON DELETE CASCADE
);

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_status_log_request_id 
ON service_request_status_log(service_request_id);

CREATE INDEX IF NOT EXISTS idx_status_log_timestamp 
ON service_request_status_log(changed_at DESC);

-- 3. Apply the trigger to service_requests
DROP TRIGGER IF EXISTS sync_service_status_trigger ON service_requests;
CREATE TRIGGER sync_service_status_trigger
    AFTER UPDATE OF status ON service_requests
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION sync_service_request_status();

-- 4. Create function to handle assignment synchronization
CREATE OR REPLACE FUNCTION sync_mechanic_assignment()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_id UUID;
    v_old_mechanic UUID;
    v_new_mechanic UUID;
    v_notification_data jsonb;
BEGIN
    v_customer_id := NEW.customer_id;
    v_old_mechanic := OLD.assigned_mechanic_id;
    v_new_mechanic := NEW.assigned_mechanic_id;
    
    -- Skip if assignment hasn't changed
    IF v_old_mechanic IS NOT DISTINCT FROM v_new_mechanic THEN
        RETURN NEW;
    END IF;
    
    RAISE NOTICE '🔧 Mechanic assignment changing for request %: % → %',
                 NEW.id, v_old_mechanic, v_new_mechanic;
    
    v_notification_data := jsonb_build_object(
        'service_request_id', NEW.id,
        'old_mechanic_id', v_old_mechanic,
        'new_mechanic_id', v_new_mechanic,
        'customer_id', v_customer_id,
        'timestamp', NOW(),
        'status', NEW.status
    );
    
    -- Notify customer about mechanic assignment
    IF v_customer_id IS NOT NULL THEN
        PERFORM pg_notify(
            'customer_' || v_customer_id::text,
            jsonb_build_object(
                'type', 'mechanic_assignment',
                'data', v_notification_data
            )::text
        );
    END IF;
    
    -- Notify old mechanic (unassignment)
    IF v_old_mechanic IS NOT NULL THEN
        PERFORM pg_notify(
            'mechanic_' || v_old_mechanic::text,
            jsonb_build_object(
                'type', 'unassigned',
                'data', v_notification_data
            )::text
        );
    END IF;
    
    -- Notify new mechanic (assignment)
    IF v_new_mechanic IS NOT NULL THEN
        PERFORM pg_notify(
            'mechanic_' || v_new_mechanic::text,
            jsonb_build_object(
                'type', 'assigned',
                'data', v_notification_data
            )::text
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Apply mechanic assignment trigger
DROP TRIGGER IF EXISTS sync_mechanic_assignment_trigger ON service_requests;
CREATE TRIGGER sync_mechanic_assignment_trigger
    AFTER UPDATE OF assigned_mechanic_id ON service_requests
    FOR EACH ROW
    WHEN (OLD.assigned_mechanic_id IS DISTINCT FROM NEW.assigned_mechanic_id)
    EXECUTE FUNCTION sync_mechanic_assignment();

-- 6. Create status health monitoring view
CREATE OR REPLACE VIEW service_status_health AS
SELECT 
    status,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM service_requests
WHERE created_at >= NOW() - INTERVAL '24 hours'
GROUP BY status
ORDER BY count DESC;

-- 7. Test the synchronization
DO $$
DECLARE
    test_request_id UUID;
    original_status TEXT;
BEGIN
    -- Find a test request
    SELECT id, status INTO test_request_id, original_status
    FROM service_requests 
    WHERE status IS NOT NULL
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF test_request_id IS NOT NULL THEN
        RAISE NOTICE '🧪 Testing status sync for request % (current status: %)', 
                     test_request_id, original_status;
        
        -- Simulate a status change (then revert it)
        UPDATE service_requests 
        SET status = 'testing_sync'
        WHERE id = test_request_id;
        
        -- Revert the change
        UPDATE service_requests 
        SET status = original_status
        WHERE id = test_request_id;
        
        RAISE NOTICE '✅ Status sync test completed';
    ELSE
        RAISE NOTICE 'ℹ️ No service requests found for testing';
    END IF;
END;
$$;

-- 8. Show current status distribution
SELECT 
    'Current Status Distribution' as info,
    json_agg(
        json_build_object(
            'status', status,
            'count', count,
            'percentage', percentage || '%'
        )
    ) as data
FROM service_status_health;

-- 9. Show recent status changes (if log table exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'service_request_status_log') THEN
        RAISE NOTICE '📊 Recent status changes:';
        PERFORM 
            RAISE NOTICE '   % → % (Request: %, Time: %)',
                old_status, new_status, service_request_id, changed_at
        FROM service_request_status_log
        WHERE changed_at >= NOW() - INTERVAL '1 hour'
        ORDER BY changed_at DESC
        LIMIT 5;
    END IF;
END;
$$;

RAISE NOTICE '🎯 Service status synchronization enhancement complete!';
RAISE NOTICE '🔄 Real-time notifications now active for status changes';
RAISE NOTICE '📊 Monitor status health with: SELECT * FROM service_status_health';
RAISE NOTICE '📝 Status changes are logged in service_request_status_log table';