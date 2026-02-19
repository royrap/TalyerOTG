-- QR Job Completion with Automatic History Recording
-- This function handles complete job completion via QR scan with automatic history recording

-- Create the RPC function for atomic job completion with history
CREATE OR REPLACE FUNCTION complete_job_with_qr_scan(
    p_completion_code_id UUID,
    p_request_id UUID,
    p_provider_id UUID,
    p_completed_at TIMESTAMP WITH TIME ZONE,
    p_scan_latitude NUMERIC DEFAULT NULL,
    p_scan_longitude NUMERIC DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_service_request RECORD;
    v_mechanic_name TEXT;
    v_shop_name TEXT;
    v_review RECORD;
BEGIN
    -- Get the service request details
    SELECT sr.*
    INTO v_service_request
    FROM service_requests sr
    WHERE sr.id = p_request_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service request not found: %', p_request_id;
    END IF;
    
    -- Get mechanic and shop names separately
    SELECT up_mechanic.first_name || ' ' || up_mechanic.last_name, s.shop_name
    INTO v_mechanic_name, v_shop_name
    FROM service_requests sr
    LEFT JOIN user_profiles up_mechanic ON sr.assigned_mechanic_id = up_mechanic.id
    LEFT JOIN shops s ON sr.shop_id = s.id
    WHERE sr.id = p_request_id;

    -- Get review if exists
    SELECT rating, comment INTO v_review
    FROM reviews 
    WHERE request_id = p_request_id;

    -- 1. Mark completion code as used
    UPDATE job_completion_codes
    SET 
        is_used = TRUE,
        used_at = p_completed_at,
        used_by_provider_id = p_provider_id,
        verification_status = 'verified',
        scan_latitude = p_scan_latitude,
        scan_longitude = p_scan_longitude
    WHERE id = p_completion_code_id;

    -- 2. Update service request status to completed
    UPDATE service_requests
    SET 
        status = 'completed',
        completed_at = p_completed_at,
        qr_scanned_at = p_completed_at,
        qr_scanned_by = p_provider_id
    WHERE id = p_request_id;

    -- 3. Record mechanic job history
    IF v_service_request.assigned_mechanic_id IS NOT NULL THEN
        INSERT INTO mechanic_job_history (
            mechanic_id,
            service_request_id,
            customer_id,
            shop_id,
            job_title,
            job_description,
            job_status,
            completed_at,
            total_amount,
            rating,
            review_text,
            created_at,
            updated_at
        ) VALUES (
            v_service_request.assigned_mechanic_id,
            v_service_request.id,
            v_service_request.customer_id,
            v_service_request.shop_id,
            COALESCE(v_service_request.title, v_service_request.service_type, 'Service Request'),
            v_service_request.description,
            'completed',
            p_completed_at,
            v_service_request.final_price,
            v_review.rating,
            v_review.comment,
            p_completed_at,
            p_completed_at
        ) ON CONFLICT (mechanic_id, service_request_id) DO NOTHING;
    END IF;

    -- 4. Record customer job history
    INSERT INTO customer_job_history (
        customer_id,
        service_request_id,
        mechanic_id,
        shop_id,
        job_title,
        job_description,
        job_status,
        completed_at,
        total_amount,
        rating,
        review_text,
        mechanic_name,
        shop_name,
        created_at,
        updated_at
    ) VALUES (
        v_service_request.customer_id,
        v_service_request.id,
        v_service_request.assigned_mechanic_id,
        v_service_request.shop_id,
        COALESCE(v_service_request.title, v_service_request.service_type, 'Service Request'),
        v_service_request.description,
        'completed',
        p_completed_at,
        v_service_request.final_price,
        v_review.rating,
        v_review.comment,
        v_mechanic_name,
        v_shop_name,
        p_completed_at,
        p_completed_at
    ) ON CONFLICT (customer_id, service_request_id) DO NOTHING;

    -- Log the completion
    RAISE NOTICE 'Job completed successfully: %, History recorded for customer: % and mechanic: %', 
        p_request_id, v_service_request.customer_id, v_service_request.assigned_mechanic_id;

    RETURN TRUE;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error completing job with QR scan: %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Add unique constraints to prevent duplicate history entries
ALTER TABLE mechanic_job_history 
ADD CONSTRAINT mechanic_job_history_unique 
UNIQUE (mechanic_id, service_request_id);

ALTER TABLE customer_job_history 
ADD CONSTRAINT customer_job_history_unique 
UNIQUE (customer_id, service_request_id);

-- Create function to handle cancelled jobs as well
CREATE OR REPLACE FUNCTION record_cancelled_job_history(
    p_request_id UUID,
    p_cancelled_at TIMESTAMP WITH TIME ZONE
) RETURNS BOOLEAN AS $$
DECLARE
    v_service_request RECORD;
    v_mechanic_name TEXT;
    v_shop_name TEXT;
BEGIN
    -- Get the service request details
    SELECT sr.*
    INTO v_service_request
    FROM service_requests sr
    WHERE sr.id = p_request_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service request not found: %', p_request_id;
    END IF;
    
    -- Get mechanic and shop names separately  
    SELECT up_mechanic.first_name || ' ' || up_mechanic.last_name, s.shop_name
    INTO v_mechanic_name, v_shop_name
    FROM service_requests sr
    LEFT JOIN user_profiles up_mechanic ON sr.assigned_mechanic_id = up_mechanic.id
    LEFT JOIN shops s ON sr.shop_id = s.id
    WHERE sr.id = p_request_id;

    -- Record mechanic job history if mechanic was assigned
    IF v_service_request.assigned_mechanic_id IS NOT NULL THEN
        INSERT INTO mechanic_job_history (
            mechanic_id,
            service_request_id,
            customer_id,
            shop_id,
            job_title,
            job_description,
            job_status,
            cancelled_at,
            total_amount,
            created_at,
            updated_at
        ) VALUES (
            v_service_request.assigned_mechanic_id,
            v_service_request.id,
            v_service_request.customer_id,
            v_service_request.shop_id,
            COALESCE(v_service_request.title, v_service_request.service_type, 'Service Request'),
            v_service_request.description,
            'cancelled',
            p_cancelled_at,
            v_service_request.final_price,
            p_cancelled_at,
            p_cancelled_at
        ) ON CONFLICT (mechanic_id, service_request_id) DO NOTHING;
    END IF;

    -- Record customer job history
    INSERT INTO customer_job_history (
        customer_id,
        service_request_id,
        mechanic_id,
        shop_id,
        job_title,
        job_description,
        job_status,
        cancelled_at,
        total_amount,
        mechanic_name,
        shop_name,
        created_at,
        updated_at
    ) VALUES (
        v_service_request.customer_id,
        v_service_request.id,
        v_service_request.assigned_mechanic_id,
        v_service_request.shop_id,
        COALESCE(v_service_request.title, v_service_request.service_type, 'Service Request'),
        v_service_request.description,
        'cancelled',
        p_cancelled_at,
        v_service_request.final_price,
        v_mechanic_name,
        v_shop_name,
        p_cancelled_at,
        p_cancelled_at
    ) ON CONFLICT (customer_id, service_request_id) DO NOTHING;

    RETURN TRUE;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error recording cancelled job history: %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Create triggers to automatically record history when jobs are completed or cancelled
CREATE OR REPLACE FUNCTION trigger_record_job_history()
RETURNS TRIGGER AS $$
BEGIN
    -- Only trigger when status changes to completed or cancelled
    IF (OLD.status IS DISTINCT FROM NEW.status) THEN
        IF NEW.status = 'completed' THEN
            -- Record completion history (will be handled by QR scan function)
            RAISE NOTICE 'Job completed: %', NEW.id;
        ELSIF NEW.status IN ('cancelled', 'canceled') THEN
            -- Record cancellation history
            PERFORM record_cancelled_job_history(NEW.id, COALESCE(NEW.cancelled_at, NOW()));
            RAISE NOTICE 'Job cancelled history recorded: %', NEW.id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if exists and create new one
DROP TRIGGER IF EXISTS service_request_history_trigger ON service_requests;
CREATE TRIGGER service_request_history_trigger
    AFTER UPDATE ON service_requests
    FOR EACH ROW
    EXECUTE FUNCTION trigger_record_job_history();

-- Test query to validate the function works
-- SELECT complete_job_with_qr_scan(
--     'completion_code_id'::UUID,
--     'request_id'::UUID, 
--     'provider_id'::UUID,
--     NOW(),
--     14.5995,  -- Sample latitude
--     120.9842  -- Sample longitude  
-- );

COMMENT ON FUNCTION complete_job_with_qr_scan IS 'Atomically completes a job via QR scan and records history for both mechanic and customer';
COMMENT ON FUNCTION record_cancelled_job_history IS 'Records job history when a job is cancelled';
COMMENT ON FUNCTION trigger_record_job_history IS 'Trigger function to automatically record job history on status changes';