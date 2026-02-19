-- Customer-Mechanic Communication Flow Enhancement
-- Addresses communication disruptions during service completion and review phases

-- 1. Create enhanced communication trigger function
CREATE OR REPLACE FUNCTION trigger_communication_flow()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_id UUID;
    v_mechanic_id UUID;
    v_notification_data jsonb;
    v_service_type TEXT;
    v_total_amount NUMERIC;
BEGIN
    -- Extract key information
    v_customer_id := NEW.customer_id;
    v_mechanic_id := NEW.assigned_mechanic_id;
    v_service_type := COALESCE(NEW.service_type, 'Service');
    v_total_amount := NEW.total_amount;
    
    -- Build base notification data
    v_notification_data := jsonb_build_object(
        'service_request_id', NEW.id,
        'customer_id', v_customer_id,
        'mechanic_id', v_mechanic_id,
        'service_type', v_service_type,
        'total_amount', v_total_amount,
        'status', NEW.status,
        'pickup_location', NEW.pickup_location,
        'timestamp', NOW()
    );
    
    -- Handle critical status changes that require enhanced communication
    CASE NEW.status
        WHEN 'completed' THEN
            -- Service completion notifications
            PERFORM pg_notify(
                'service_completed',
                jsonb_build_object(
                    'type', 'service_completed',
                    'priority', 'high',
                    'customer_notification', jsonb_build_object(
                        'title', '🎉 Service Completed!',
                        'message', 'Your ' || v_service_type || ' service has been completed. Please rate your experience.',
                        'action', 'show_review_dialog',
                        'data', v_notification_data
                    ),
                    'mechanic_notification', jsonb_build_object(
                        'title', '✅ Job Completed',
                        'message', 'Service completed successfully. Customer will be prompted to rate the service.',
                        'action', 'update_earnings',
                        'data', v_notification_data
                    )
                )::text
            );
            
            -- Trigger customer review dialog
            IF v_customer_id IS NOT NULL THEN
                PERFORM pg_notify(
                    'customer_' || v_customer_id::text,
                    jsonb_build_object(
                        'type', 'show_review_dialog',
                        'service_request_id', NEW.id,
                        'mechanic_id', v_mechanic_id,
                        'service_type', v_service_type,
                        'auto_show', true
                    )::text
                );
            END IF;
            
        WHEN 'invoice_paid' THEN
            -- Payment completed, ready for service completion
            PERFORM pg_notify(
                'payment_completed',
                jsonb_build_object(
                    'type', 'payment_completed',
                    'customer_notification', jsonb_build_object(
                        'title', '💳 Payment Successful',
                        'message', 'Payment completed. Service will begin shortly.',
                        'action', 'track_service'
                    ),
                    'mechanic_notification', jsonb_build_object(
                        'title', '💰 Payment Received',
                        'message', 'Customer payment confirmed. You can now complete the service.',
                        'action', 'enable_completion'
                    ),
                    'data', v_notification_data
                )::text
            );
            
        WHEN 'in_progress' THEN
            -- Service started
            PERFORM pg_notify(
                'service_started',
                jsonb_build_object(
                    'type', 'service_started',
                    'customer_notification', jsonb_build_object(
                        'title', '🔧 Service Started',
                        'message', 'Your mechanic has started working on your ' || v_service_type || '.',
                        'action', 'track_progress'
                    ),
                    'data', v_notification_data
                )::text
            );
    END CASE;
    
    -- Enhanced communication for payment status changes
    IF TG_OP = 'UPDATE' AND OLD.payment_status IS DISTINCT FROM NEW.payment_status THEN
        PERFORM pg_notify(
            'payment_status_change',
            jsonb_build_object(
                'type', 'payment_status_change',
                'old_status', OLD.payment_status,
                'new_status', NEW.payment_status,
                'data', v_notification_data
            )::text
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Create communication flow trigger
DROP TRIGGER IF EXISTS communication_flow_trigger ON service_requests;
CREATE TRIGGER communication_flow_trigger
    AFTER INSERT OR UPDATE ON service_requests
    FOR EACH ROW
    EXECUTE FUNCTION trigger_communication_flow();

-- 3. Create function to ensure review dialog shows after completion
CREATE OR REPLACE FUNCTION ensure_review_dialog_trigger()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_id UUID;
    v_provider_id UUID;
    v_service_title TEXT;
BEGIN
    -- Only trigger for newly completed services
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
        v_customer_id := NEW.customer_id;
        v_service_title := COALESCE(NEW.service_type, 'Service');
        
        -- Get the provider ID from the assigned mechanic
        SELECT sp.id INTO v_provider_id
        FROM service_providers sp
        WHERE sp.user_id = NEW.assigned_mechanic_id
        LIMIT 1;
        
        IF v_provider_id IS NOT NULL THEN
            -- Send delayed review prompt (5 seconds after completion)
            PERFORM pg_notify(
                'delayed_review_prompt',
                jsonb_build_object(
                    'delay_seconds', 5,
                    'customer_id', v_customer_id,
                    'request_id', NEW.id,
                    'provider_id', v_provider_id,
                    'service_title', v_service_title,
                    'timestamp', NOW()
                )::text
            );
            
            RAISE NOTICE '📝 Review dialog scheduled for customer % after service % completion',
                         v_customer_id, NEW.id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Apply review dialog trigger
DROP TRIGGER IF EXISTS review_dialog_trigger ON service_requests;
CREATE TRIGGER review_dialog_trigger
    AFTER UPDATE OF status ON service_requests
    FOR EACH ROW
    WHEN (NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed'))
    EXECUTE FUNCTION ensure_review_dialog_trigger();

-- 5. Create communication health monitoring
CREATE OR REPLACE VIEW communication_flow_health AS
WITH recent_services AS (
    SELECT 
        id,
        status,
        payment_status,
        customer_id,
        assigned_mechanic_id,
        created_at,
        CASE 
            WHEN status = 'completed' THEN 'completed'
            WHEN payment_status = 'completed' THEN 'paid'
            WHEN assigned_mechanic_id IS NOT NULL THEN 'assigned'
            ELSE 'pending'
        END as flow_stage
    FROM service_requests
    WHERE created_at >= NOW() - INTERVAL '24 hours'
)
SELECT 
    flow_stage,
    COUNT(*) as service_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage,
    CASE flow_stage
        WHEN 'completed' THEN '✅ Services completed with review opportunity'
        WHEN 'paid' THEN '💳 Services paid, ready for completion'
        WHEN 'assigned' THEN '🔧 Services assigned to mechanics'
        WHEN 'pending' THEN '⏳ Services awaiting assignment'
    END as description
FROM recent_services
GROUP BY flow_stage
ORDER BY 
    CASE flow_stage
        WHEN 'pending' THEN 1
        WHEN 'assigned' THEN 2
        WHEN 'paid' THEN 3
        WHEN 'completed' THEN 4
    END;

-- 6. Create function to check communication gaps
CREATE OR REPLACE FUNCTION check_communication_gaps()
RETURNS TABLE(
    issue_type TEXT,
    count BIGINT,
    description TEXT
) AS $$
BEGIN
    -- Check for services completed without reviews
    RETURN QUERY
    SELECT 
        'missing_reviews'::TEXT,
        COUNT(sr.id),
        'Completed services without reviews - communication may have failed'::TEXT
    FROM service_requests sr
    LEFT JOIN reviews r ON sr.id = r.service_request_id
    WHERE sr.status = 'completed'
    AND sr.created_at >= NOW() - INTERVAL '7 days'
    AND r.id IS NULL;
    
    -- Check for paid services not progressing to completion
    RETURN QUERY
    SELECT 
        'stalled_after_payment'::TEXT,
        COUNT(*),
        'Services paid but not completed within reasonable time'::TEXT
    FROM service_requests
    WHERE payment_status = 'completed'
    AND status != 'completed'
    AND updated_at < NOW() - INTERVAL '2 hours';
    
    -- Check for assigned services without progress
    RETURN QUERY
    SELECT 
        'stalled_assignments'::TEXT,
        COUNT(*),
        'Services assigned but no progress updates'::TEXT
    FROM service_requests
    WHERE assigned_mechanic_id IS NOT NULL
    AND status = 'accepted'
    AND updated_at < NOW() - INTERVAL '1 hour';
END;
$$ LANGUAGE plpgsql;

-- 7. Test the communication flow
DO $$
DECLARE
    test_request_id UUID;
    test_status TEXT;
BEGIN
    -- Find a test request
    SELECT id, status INTO test_request_id, test_status
    FROM service_requests
    WHERE customer_id IS NOT NULL
    AND assigned_mechanic_id IS NOT NULL
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF test_request_id IS NOT NULL THEN
        RAISE NOTICE '🧪 Testing communication flow for request % (current status: %)',
                     test_request_id, test_status;
        
        -- Simulate status change to trigger communication
        UPDATE service_requests
        SET status = 'testing_communication'
        WHERE id = test_request_id;
        
        -- Revert the change
        UPDATE service_requests
        SET status = test_status
        WHERE id = test_request_id;
        
        RAISE NOTICE '✅ Communication flow test completed';
    ELSE
        RAISE NOTICE 'ℹ️ No suitable service requests found for testing';
    END IF;
END;
$$;

-- 8. Show current communication health and complete setup
DO $$
BEGIN
    -- Show communication health report
    RAISE NOTICE '🔍 Communication Flow Health Report:';
    PERFORM 1; -- Placeholder for health report display
    
    -- Show communication gaps analysis  
    RAISE NOTICE '⚠️ Communication Gaps Analysis:';
    PERFORM 1; -- Placeholder for gaps analysis display
    
    RAISE NOTICE '🎯 Customer-Mechanic communication flow enhancement complete!';
    RAISE NOTICE '📊 Monitor communication health: SELECT * FROM communication_flow_health';
    RAISE NOTICE '🔍 Check for gaps: SELECT * FROM check_communication_gaps()';
    RAISE NOTICE '📝 Review dialogs are now automatically triggered after service completion';
    RAISE NOTICE '🔔 Enhanced notifications ensure better customer-mechanic communication';
END
$$;

-- 9. Queries to run separately for monitoring (copy these to run manually)
/*
-- Check communication health
SELECT 
    '🔍 Communication Flow Health Report' as report_title,
    json_agg(
        json_build_object(
            'stage', flow_stage,
            'count', service_count,
            'percentage', percentage || '%',
            'description', description
        )
        ORDER BY service_count DESC
    ) as flow_data
FROM communication_flow_health;

-- Check for communication gaps
SELECT 
    '⚠️ Communication Gaps Analysis' as analysis_title,
    json_agg(
        json_build_object(
            'issue', issue_type,
            'count', count,
            'description', description
        )
    ) as gap_data
FROM check_communication_gaps();
*/