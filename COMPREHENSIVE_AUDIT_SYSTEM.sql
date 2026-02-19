-- =====================================================
-- COMPREHENSIVE AUDIT LOGGING SYSTEM
-- =====================================================
-- Tracks all user movements and actions for mechanics, customers, and shop owners
-- Implements standard audit logging with database functions and triggers
-- =====================================================

-- 1. Create the audit_logs table
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NULL,
    role character varying(50) NOT NULL,
    action text NOT NULL,
    table_name character varying(100) NULL,
    record_id uuid NULL,
    ip_address character varying(45) NULL,
    user_agent text NULL,
    session_id text NULL,
    old_values jsonb NULL,
    new_values jsonb NULL,
    additional_data jsonb NULL DEFAULT '{}'::jsonb,
    success boolean NULL DEFAULT true,
    error_message text NULL,
    created_at timestamp with time zone NULL DEFAULT now(),
    CONSTRAINT audit_logs_pkey PRIMARY KEY (id),
    CONSTRAINT audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES user_profiles (id),
    CONSTRAINT audit_logs_role_check CHECK (
        (role)::text = ANY (
            ARRAY[
                'customer'::character varying,
                'mechanic'::character varying,
                'talyer_owner'::character varying,
                'admin'::character varying,
                'super_admin'::character varying,
                'system'::character varying
            ]::text[]
        )
    )
) TABLESPACE pg_default;

-- 2. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON public.audit_logs USING btree (user_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_audit_logs_role ON public.audit_logs USING btree (role) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON public.audit_logs USING btree (action) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_audit_logs_table_name ON public.audit_logs USING btree (table_name) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_audit_logs_record_id ON public.audit_logs USING btree (record_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs USING btree (created_at DESC) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_action ON public.audit_logs USING btree (user_id, action) TABLESPACE pg_default;

-- 3. Core audit logging function
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
$$ LANGUAGE plpgsql;

-- 4. Authentication audit functions
CREATE OR REPLACE FUNCTION log_user_login(
    p_user_id uuid,
    p_role text,
    p_ip_address text DEFAULT NULL,
    p_user_agent text DEFAULT NULL,
    p_session_id text DEFAULT NULL,
    p_success boolean DEFAULT true,
    p_error_message text DEFAULT NULL
) RETURNS uuid AS $$
BEGIN
    RETURN log_audit_action(
        p_user_id,
        p_role,
        'USER_LOGIN',
        'user_profiles',
        p_user_id,
        p_ip_address,
        p_user_agent,
        p_session_id,
        NULL,
        jsonb_build_object('login_time', NOW()),
        jsonb_build_object('device_info', p_user_agent),
        p_success,
        p_error_message
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION log_user_logout(
    p_user_id uuid,
    p_role text,
    p_session_id text DEFAULT NULL
) RETURNS uuid AS $$
BEGIN
    RETURN log_audit_action(
        p_user_id,
        p_role,
        'USER_LOGOUT',
        'user_profiles',
        p_user_id,
        NULL,
        NULL,
        p_session_id,
        NULL,
        jsonb_build_object('logout_time', NOW()),
        '{}'::jsonb,
        true,
        NULL
    );
END;
$$ LANGUAGE plpgsql;

-- 5. Service request audit functions
CREATE OR REPLACE FUNCTION log_service_request_action(
    p_user_id uuid,
    p_role text,
    p_action text,
    p_request_id uuid,
    p_old_values jsonb DEFAULT NULL,
    p_new_values jsonb DEFAULT NULL,
    p_additional_data jsonb DEFAULT '{}'::jsonb
) RETURNS uuid AS $$
BEGIN
    RETURN log_audit_action(
        p_user_id,
        p_role,
        p_action,
        'service_requests',
        p_request_id,
        NULL,
        NULL,
        NULL,
        p_old_values,
        p_new_values,
        p_additional_data,
        true,
        NULL
    );
END;
$$ LANGUAGE plpgsql;

-- 6. QR code audit functions
CREATE OR REPLACE FUNCTION log_qr_code_action(
    p_user_id uuid,
    p_role text,
    p_action text,
    p_qr_code_id uuid,
    p_completion_code text DEFAULT NULL,
    p_service_request_id uuid DEFAULT NULL,
    p_additional_data jsonb DEFAULT '{}'::jsonb
) RETURNS uuid AS $$
BEGIN
    RETURN log_audit_action(
        p_user_id,
        p_role,
        p_action,
        'job_completion_codes',
        p_qr_code_id,
        NULL,
        NULL,
        NULL,
        NULL,
        jsonb_build_object(
            'completion_code', p_completion_code,
            'service_request_id', p_service_request_id
        ),
        p_additional_data,
        true,
        NULL
    );
END;
$$ LANGUAGE plpgsql;

-- 7. Location tracking audit function
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
$$ LANGUAGE plpgsql;

-- 8. Payment and earnings audit function
CREATE OR REPLACE FUNCTION log_earnings_action(
    p_user_id uuid,
    p_role text,
    p_action text,
    p_service_request_id uuid,
    p_amount decimal,
    p_earnings_breakdown jsonb DEFAULT NULL
) RETURNS uuid AS $$
BEGIN
    RETURN log_audit_action(
        p_user_id,
        p_role,
        p_action,
        'service_requests',
        p_service_request_id,
        NULL,
        NULL,
        NULL,
        NULL,
        jsonb_build_object(
            'amount', p_amount,
            'earnings_breakdown', p_earnings_breakdown,
            'timestamp', NOW()
        ),
        '{}'::jsonb,
        true,
        NULL
    );
END;
$$ LANGUAGE plpgsql;

-- 9. Shop management audit function
CREATE OR REPLACE FUNCTION log_shop_action(
    p_user_id uuid,
    p_role text,
    p_action text,
    p_shop_id uuid,
    p_old_values jsonb DEFAULT NULL,
    p_new_values jsonb DEFAULT NULL,
    p_additional_data jsonb DEFAULT '{}'::jsonb
) RETURNS uuid AS $$
BEGIN
    RETURN log_audit_action(
        p_user_id,
        p_role,
        p_action,
        'shops',
        p_shop_id,
        NULL,
        NULL,
        NULL,
        p_old_values,
        p_new_values,
        p_additional_data,
        true,
        NULL
    );
END;
$$ LANGUAGE plpgsql;

-- 10. Profile update audit function
CREATE OR REPLACE FUNCTION log_profile_update(
    p_user_id uuid,
    p_role text,
    p_old_values jsonb,
    p_new_values jsonb
) RETURNS uuid AS $$
BEGIN
    RETURN log_audit_action(
        p_user_id,
        p_role,
        'PROFILE_UPDATE',
        'user_profiles',
        p_user_id,
        NULL,
        NULL,
        NULL,
        p_old_values,
        p_new_values,
        '{}'::jsonb,
        true,
        NULL
    );
END;
$$ LANGUAGE plpgsql;

-- 11. Audit report functions
CREATE OR REPLACE FUNCTION get_user_activity_report(
    p_user_id uuid,
    p_start_date timestamp DEFAULT NULL,
    p_end_date timestamp DEFAULT NULL
) RETURNS TABLE (
    log_id uuid,
    action text,
    table_name character varying,
    created_at timestamp with time zone,
    success boolean,
    additional_info jsonb
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        al.id as log_id,
        al.action,
        al.table_name,
        al.created_at,
        al.success,
        al.additional_data as additional_info
    FROM audit_logs al
    WHERE al.user_id = p_user_id
    AND (p_start_date IS NULL OR al.created_at >= p_start_date)
    AND (p_end_date IS NULL OR al.created_at <= p_end_date)
    ORDER BY al.created_at DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_system_activity_summary(
    p_start_date timestamp DEFAULT NOW() - INTERVAL '7 days',
    p_end_date timestamp DEFAULT NOW()
) RETURNS TABLE (
    role character varying,
    action text,
    count bigint,
    success_rate decimal
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        al.role,
        al.action,
        COUNT(*) as count,
        ROUND(
            (COUNT(*) FILTER (WHERE al.success = true)::decimal / COUNT(*)) * 100, 
            2
        ) as success_rate
    FROM audit_logs al
    WHERE al.created_at BETWEEN p_start_date AND p_end_date
    GROUP BY al.role, al.action
    ORDER BY al.role, count DESC;
END;
$$ LANGUAGE plpgsql;

-- 12. Triggers for automatic auditing of critical tables

-- Service requests trigger
CREATE OR REPLACE FUNCTION audit_service_requests_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM log_service_request_action(
            NEW.customer_id,
            'customer',
            'SERVICE_REQUEST_CREATED',
            NEW.id,
            NULL,
            row_to_json(NEW)::jsonb
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        PERFORM log_service_request_action(
            COALESCE(NEW.assigned_mechanic_id, NEW.customer_id),
            CASE 
                WHEN NEW.assigned_mechanic_id IS NOT NULL THEN 'mechanic'
                ELSE 'customer'
            END,
            'SERVICE_REQUEST_UPDATED',
            NEW.id,
            row_to_json(OLD)::jsonb,
            row_to_json(NEW)::jsonb
        );
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS service_requests_audit_trigger ON service_requests;

-- Create the trigger
CREATE TRIGGER service_requests_audit_trigger
    AFTER INSERT OR UPDATE ON service_requests
    FOR EACH ROW
    EXECUTE FUNCTION audit_service_requests_trigger();

-- QR codes trigger
CREATE OR REPLACE FUNCTION audit_qr_codes_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM log_qr_code_action(
            NEW.customer_id,
            'customer',
            'QR_CODE_GENERATED',
            NEW.id,
            NEW.completion_code,
            NEW.request_id
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' AND OLD.is_used = false AND NEW.is_used = true THEN
        PERFORM log_qr_code_action(
            NEW.customer_id,
            'customer',
            'QR_CODE_USED',
            NEW.id,
            NEW.completion_code,
            NEW.request_id,
            jsonb_build_object('used_at', NEW.used_at)
        );
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS qr_codes_audit_trigger ON job_completion_codes;

-- Create the trigger
CREATE TRIGGER qr_codes_audit_trigger
    AFTER INSERT OR UPDATE ON job_completion_codes
    FOR EACH ROW
    EXECUTE FUNCTION audit_qr_codes_trigger();

-- 13. Clean up old audit logs (retention policy)
CREATE OR REPLACE FUNCTION cleanup_old_audit_logs(
    p_retention_days integer DEFAULT 90
) RETURNS integer AS $$
DECLARE
    v_deleted_count integer;
BEGIN
    DELETE FROM audit_logs 
    WHERE created_at < (NOW() - (p_retention_days || ' days')::interval);
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    -- Log the cleanup action
    PERFORM log_audit_action(
        NULL,
        'system',
        'AUDIT_LOG_CLEANUP',
        'audit_logs',
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        jsonb_build_object(
            'deleted_count', v_deleted_count,
            'retention_days', p_retention_days,
            'cleanup_date', NOW()
        ),
        '{}'::jsonb,
        true,
        NULL
    );
    
    RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT SELECT, INSERT ON audit_logs TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- Initial system audit log
SELECT log_audit_action(
    NULL,
    'system',
    'AUDIT_SYSTEM_INITIALIZED',
    'audit_logs',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    jsonb_build_object('initialization_date', NOW()),
    '{}'::jsonb,
    true,
    NULL
);

-- Success message
SELECT 'Comprehensive audit logging system has been successfully implemented!' as status;