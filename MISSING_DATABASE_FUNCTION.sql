-- ========================================
-- MISSING DATABASE FUNCTION: log_user_login
-- ========================================
-- This function is called during user login to record login activity
-- in the account_security_logs table for audit and security purposes.
--
-- Error from logs:
-- "Could not find the function public.log_user_login(...)"
-- 
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Open Supabase Dashboard
-- 2. Go to SQL Editor
-- 3. Run this SQL script
-- 4. Test by logging in to the app
-- ========================================

CREATE OR REPLACE FUNCTION public.log_user_login(
    p_user_id uuid,
    p_success boolean,
    p_role text DEFAULT NULL,
    p_ip_address inet DEFAULT NULL,
    p_user_agent text DEFAULT NULL,
    p_session_id text DEFAULT NULL,
    p_error_message text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_log_id uuid;
    v_action_type text;
BEGIN
    -- Determine action type based on success
    IF p_success THEN
        v_action_type := 'login';
    ELSE
        v_action_type := 'failed_login';
    END IF;

    -- Insert login log into account_security_logs
    INSERT INTO public.account_security_logs (
        user_id,
        action_type,
        ip_address,
        user_agent,
        session_id,
        success,
        failure_reason,
        details,
        created_at
    )
    VALUES (
        p_user_id,
        v_action_type,
        p_ip_address,
        p_user_agent,
        p_session_id,
        p_success,
        CASE WHEN NOT p_success THEN p_error_message ELSE NULL END,
        jsonb_build_object(
            'role', COALESCE(p_role, 'unknown'),
            'timestamp', NOW(),
            'success', p_success
        ),
        NOW()
    )
    RETURNING id INTO v_log_id;

    -- Return the log ID
    RETURN v_log_id;

EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't fail the login process
        RAISE WARNING 'Error logging user login: %', SQLERRM;
        RETURN NULL;
END;
$$;

-- ========================================
-- GRANT PERMISSIONS
-- ========================================
-- Allow authenticated users to log their own logins
GRANT EXECUTE ON FUNCTION public.log_user_login TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_user_login TO service_role;

-- ========================================
-- COMMENT
-- ========================================
COMMENT ON FUNCTION public.log_user_login IS 
'Logs user login attempts (successful and failed) to account_security_logs table for security auditing. Called during authentication process.';

-- ========================================
-- TEST QUERY (Optional - run after deployment)
-- ========================================
-- Test successful login log:
-- SELECT public.log_user_login(
--     auth.uid(),  -- current user ID
--     true,        -- success
--     'customer',  -- role
--     '127.0.0.1'::inet,  -- IP address
--     'Mozilla/5.0',      -- user agent
--     'session_123',      -- session ID
--     NULL                -- no error message
-- );

-- Verify the log was created:
-- SELECT * FROM public.account_security_logs 
-- WHERE user_id = auth.uid() 
-- ORDER BY created_at DESC 
-- LIMIT 1;

-- ========================================
-- ADDITIONAL HELPER FUNCTION (Optional)
-- ========================================
-- Function to get recent login history for a user
CREATE OR REPLACE FUNCTION public.get_user_login_history(
    p_user_id uuid,
    p_limit integer DEFAULT 10
)
RETURNS TABLE (
    id uuid,
    action_type text,
    ip_address inet,
    user_agent text,
    success boolean,
    failure_reason text,
    created_at timestamp with time zone
)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT 
        id,
        action_type,
        ip_address,
        user_agent,
        success,
        failure_reason,
        created_at
    FROM public.account_security_logs
    WHERE user_id = p_user_id
      AND action_type IN ('login', 'failed_login')
    ORDER BY created_at DESC
    LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_login_history TO authenticated;

COMMENT ON FUNCTION public.get_user_login_history IS 
'Retrieves recent login history for a user, including successful and failed attempts.';

-- ========================================
-- DEPLOYMENT COMPLETE
-- ========================================
-- After running this script:
-- ✅ log_user_login function created
-- ✅ Permissions granted
-- ✅ Helper function for viewing login history created
-- 
-- The login error should now be resolved!
-- ========================================
