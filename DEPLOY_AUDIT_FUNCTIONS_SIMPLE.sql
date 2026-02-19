-- =====================================================
-- DEPLOY MISSING AUDIT FUNCTIONS - QUICK FIX
-- =====================================================
-- Run this in Supabase SQL Editor to fix audit logging errors
-- This creates the missing log_audit_action and log_location_update functions
-- =====================================================

-- 1. Core audit logging function
CREATE OR REPLACE FUNCTION log_audit_action(
    p_user_id uuid,
    p_role text,
    p_action text,
    p_table_name text DEFAULT NULL,
    p_record_id uuid DEFAULT NULL,
    p_ip_address text DEFAULT NULL,
    p_user_agent text DEFAULT NULL,
    p_session_id text DEFAULT NULL,
    p_old_values jsonb DEFAULT NULL,
    p_new_values jsonb DEFAULT NULL,
    p_additional_data jsonb DEFAULT '{}'::jsonb,
    p_success boolean DEFAULT true,
    p_error_message text DEFAULT NULL
) RETURNS uuid AS $$
DECLARE
    v_log_id uuid;
BEGIN
    INSERT INTO audit_logs (
        user_id,
        role,
        action,
        table_name,
        record_id,
        ip_address,
        user_agent,
        session_id,
        old_values,
        new_values,
        additional_data,
        success,
        error_message,
        created_at
    ) VALUES (
        p_user_id,
        p_role,
        p_action,
        p_table_name,
        p_record_id,
        p_ip_address,
        p_user_agent,
        p_session_id,
        p_old_values,
        p_new_values,
        p_additional_data,
        p_success,
        p_error_message,
        NOW()
    ) RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Location tracking audit function
CREATE OR REPLACE FUNCTION log_location_update(
    p_user_id uuid,
    p_role text,
    p_latitude decimal,
    p_longitude decimal,
    p_activity text DEFAULT NULL
) RETURNS uuid AS $$
BEGIN
    RETURN log_audit_action(
        p_user_id,
        p_role,
        'LOCATION_UPDATE',
        'user_profiles',
        p_user_id,
        NULL,
        NULL,
        NULL,
        NULL,
        jsonb_build_object(
            'latitude', p_latitude,
            'longitude', p_longitude,
            'activity', p_activity,
            'timestamp', NOW()
        ),
        '{}'::jsonb,
        true,
        NULL
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION log_audit_action TO authenticated;
GRANT EXECUTE ON FUNCTION log_audit_action TO anon;
GRANT EXECUTE ON FUNCTION log_location_update TO authenticated;
GRANT EXECUTE ON FUNCTION log_location_update TO anon;

-- 4. Verify deployment
SELECT 
    'Audit functions deployed successfully!' as status,
    COUNT(*) FILTER (WHERE proname = 'log_audit_action') as log_audit_action_exists,
    COUNT(*) FILTER (WHERE proname = 'log_location_update') as log_location_update_exists
FROM pg_proc 
WHERE proname IN ('log_audit_action', 'log_location_update');
