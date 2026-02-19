-- =====================================================
-- QR COMPLETION FLOW DATABASE FUNCTIONS
-- =====================================================
-- Integrates QR completion with the Angkas-style earnings system
-- Ensures atomic job completion with proper status updates
-- =====================================================

BEGIN;

-- =====================================================
-- FUNCTION: Complete job with QR scan (atomic operation)
-- =====================================================

CREATE OR REPLACE FUNCTION complete_job_with_qr_scan(
    p_completion_code_id UUID,
    p_request_id UUID,
    p_provider_id UUID,
    p_completed_at TIMESTAMPTZ DEFAULT NOW(),
    p_scan_latitude NUMERIC DEFAULT NULL,
    p_scan_longitude NUMERIC DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_service_request RECORD;
    v_completion_code RECORD;
    v_mechanic_id UUID;
    v_final_price NUMERIC := 0.0;
    v_earnings_breakdown RECORD;
    v_result JSON;
BEGIN
    -- Get completion code details
    SELECT * INTO v_completion_code
    FROM job_completion_codes 
    WHERE id = p_completion_code_id 
    AND is_used = FALSE 
    AND expires_at > NOW();
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Invalid or expired completion code'
        );
    END IF;
    
    -- Get service request details
    SELECT * INTO v_service_request
    FROM service_requests 
    WHERE id = p_request_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Service request not found'
        );
    END IF;
    
    -- Determine the mechanic ID (provider could be mechanic or shop owner)
    v_mechanic_id := COALESCE(v_service_request.assigned_mechanic_id, p_provider_id);
    v_final_price := COALESCE(v_service_request.final_price, 0.0);
    
    -- Calculate earnings breakdown using existing function
    SELECT * INTO v_earnings_breakdown 
    FROM calculate_earnings_breakdown(v_final_price);
    
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
    
    -- 2. Update service request status
    UPDATE service_requests 
    SET 
        status = 'completed',
        completed_at = p_completed_at,
        service_completion_time = p_completed_at,
        qr_scanned_at = p_completed_at,
        qr_scanned_by = p_provider_id,
        mechanic_earnings = v_earnings_breakdown.mechanic_earnings,
        shop_earnings = v_earnings_breakdown.shop_earnings,
        platform_fee = v_earnings_breakdown.platform_fee,
        fee_breakdown_calculated = TRUE,
        updated_at = p_completed_at
    WHERE id = p_request_id;
    
    -- 3. Insert/Update mechanic job history with earnings
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
        mechanic_earnings,
        shop_earnings,
        platform_fee,
        fee_percentage_mechanic,
        fee_percentage_shop,
        fee_percentage_platform,
        created_at,
        updated_at
    ) VALUES (
        v_mechanic_id,
        v_service_request.id,
        v_service_request.customer_id,
        v_service_request.shop_id,
        COALESCE(v_service_request.title, v_service_request.service_type, 'Service Request'),
        v_service_request.description,
        'completed',
        p_completed_at,
        v_final_price,
        v_earnings_breakdown.mechanic_earnings,
        v_earnings_breakdown.shop_earnings,
        v_earnings_breakdown.platform_fee,
        75.00,
        20.00,
        5.00,
        p_completed_at,
        p_completed_at
    )
    ON CONFLICT (service_request_id, mechanic_id) 
    DO UPDATE SET
        job_status = 'completed',
        completed_at = p_completed_at,
        total_amount = v_final_price,
        mechanic_earnings = v_earnings_breakdown.mechanic_earnings,
        shop_earnings = v_earnings_breakdown.shop_earnings,
        platform_fee = v_earnings_breakdown.platform_fee,
        updated_at = p_completed_at;
    
    -- 4. Insert/Update customer job history
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
        mechanic_name,
        shop_name,
        created_at,
        updated_at
    ) 
    SELECT 
        v_service_request.customer_id,
        v_service_request.id,
        v_mechanic_id,
        v_service_request.shop_id,
        COALESCE(v_service_request.title, v_service_request.service_type, 'Service Request'),
        v_service_request.description,
        'completed',
        p_completed_at,
        v_final_price,
        COALESCE(up.first_name || ' ' || up.last_name, 'Mechanic') as mechanic_name,
        s.shop_name,
        p_completed_at,
        p_completed_at
    FROM user_profiles up 
    LEFT JOIN shops s ON s.id = v_service_request.shop_id
    WHERE up.id = v_mechanic_id
    ON CONFLICT (service_request_id, customer_id)
    DO UPDATE SET
        job_status = 'completed',
        completed_at = p_completed_at,
        total_amount = v_final_price,
        updated_at = p_completed_at;
    
    -- 5. Create service completion record
    INSERT INTO service_completions (
        request_id,
        mechanic_id,
        customer_id,
        completion_code,
        qr_code_data,
        is_scanned,
        scanned_at,
        verification_status,
        created_at,
        expires_at
    ) VALUES (
        v_service_request.id,
        v_mechanic_id,
        v_service_request.customer_id,
        v_completion_code.completion_code,
        'ROADAID_COMPLETED:' || v_service_request.id || ':' || v_completion_code.completion_code,
        TRUE,
        p_completed_at,
        'verified',
        p_completed_at,
        p_completed_at + INTERVAL '1 hour'
    )
    ON CONFLICT (request_id, mechanic_id) 
    DO UPDATE SET
        is_scanned = TRUE,
        scanned_at = p_completed_at,
        verification_status = 'verified';
    
    -- Return success result with earnings info
    v_result := json_build_object(
        'success', true,
        'request_id', p_request_id,
        'mechanic_id', v_mechanic_id,
        'completed_at', p_completed_at,
        'earnings', json_build_object(
            'total_amount', v_final_price,
            'mechanic_earnings', v_earnings_breakdown.mechanic_earnings,
            'shop_earnings', v_earnings_breakdown.shop_earnings,
            'platform_fee', v_earnings_breakdown.platform_fee
        )
    );
    
    RETURN v_result;
    
EXCEPTION WHEN OTHERS THEN
    -- Log the error and return failure
    RAISE NOTICE 'Error completing job with QR scan: %', SQLERRM;
    RETURN json_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNCTION: Get QR completion status
-- =====================================================

CREATE OR REPLACE FUNCTION get_qr_completion_status(p_completion_code TEXT)
RETURNS JSON AS $$
DECLARE
    v_status RECORD;
    v_result JSON;
BEGIN
    SELECT 
        jcc.*,
        sr.status as service_status,
        sr.title as service_title,
        sr.final_price,
        up.first_name || ' ' || up.last_name as customer_name
    INTO v_status
    FROM job_completion_codes jcc
    JOIN service_requests sr ON sr.id = jcc.request_id
    JOIN user_profiles up ON up.id = jcc.customer_id
    WHERE jcc.completion_code = p_completion_code;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'found', false,
            'error', 'Completion code not found'
        );
    END IF;
    
    v_result := json_build_object(
        'found', true,
        'is_used', v_status.is_used,
        'is_expired', v_status.expires_at < NOW(),
        'service_status', v_status.service_status,
        'service_title', v_status.service_title,
        'customer_name', v_status.customer_name,
        'final_price', v_status.final_price,
        'created_at', v_status.created_at,
        'expires_at', v_status.expires_at,
        'used_at', v_status.used_at
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNCTION: Validate mechanic authorization for QR completion
-- =====================================================

CREATE OR REPLACE FUNCTION validate_qr_completion_auth(
    p_completion_code TEXT,
    p_provider_id UUID
)
RETURNS JSON AS $$
DECLARE
    v_request RECORD;
    v_provider RECORD;
    v_is_authorized BOOLEAN := FALSE;
BEGIN
    -- Get service request details
    SELECT 
        sr.*,
        jcc.completion_code
    INTO v_request
    FROM job_completion_codes jcc
    JOIN service_requests sr ON sr.id = jcc.request_id
    WHERE jcc.completion_code = p_completion_code
    AND jcc.is_used = FALSE
    AND jcc.expires_at > NOW();
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'authorized', false,
            'error', 'Invalid or expired completion code'
        );
    END IF;
    
    -- Get provider details
    SELECT * INTO v_provider
    FROM user_profiles
    WHERE id = p_provider_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'authorized', false,
            'error', 'Provider not found'
        );
    END IF;
    
    -- Check authorization
    -- 1. Direct assignment to this mechanic
    IF v_request.assigned_mechanic_id = p_provider_id THEN
        v_is_authorized := TRUE;
    -- 2. Same shop membership
    ELSIF v_request.shop_id IS NOT NULL AND v_provider.shop_id = v_request.shop_id THEN
        v_is_authorized := TRUE;
    -- 3. Shop owner authorization
    ELSIF v_provider.user_type = 'talyer_owner' THEN
        -- Check if they own the shop for this request
        IF EXISTS (
            SELECT 1 FROM shops 
            WHERE id = v_request.shop_id 
            AND owner_id = p_provider_id
        ) THEN
            v_is_authorized := TRUE;
        END IF;
    END IF;
    
    RETURN json_build_object(
        'authorized', v_is_authorized,
        'request_id', v_request.id,
        'service_title', v_request.title,
        'assigned_mechanic_id', v_request.assigned_mechanic_id,
        'shop_id', v_request.shop_id,
        'provider_type', v_provider.user_type
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- SUCCESS MESSAGES
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ QR COMPLETION FLOW DATABASE FUNCTIONS CREATED';
    RAISE NOTICE '🎯 Functions: complete_job_with_qr_scan, get_qr_completion_status, validate_qr_completion_auth';
    RAISE NOTICE '💰 Integrated with Angkas-style earnings system (75%% mechanic, 20%% shop, 5%% platform)';
    RAISE NOTICE '🔧 Atomic job completion ensures data consistency';
END $$;

COMMIT;