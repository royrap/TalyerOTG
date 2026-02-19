-- ============================================================================
-- FIX QR VERIFICATION TRIGGER - ADMIN ACTIVITY LOGS ISSUE
-- ============================================================================
-- Date: October 6, 2025
-- Issue: Database trigger trying to log mechanic QR scans as admin actions
-- Error: "null value in column admin_id violates not-null constraint"
-- ============================================================================

-- Step 1: Find and disable the problematic trigger
-- ----------------------------------------------------------------------------

-- List all triggers on job_completion_codes table
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'job_completion_codes'
ORDER BY trigger_name;

-- Expected output: Should show a trigger that inserts into admin_activity_logs


-- Step 2: Drop the problematic trigger (if found)
-- ----------------------------------------------------------------------------
-- Uncomment and run this after identifying the trigger name:

-- DROP TRIGGER IF EXISTS log_qr_verification_trigger ON job_completion_codes;
-- DROP TRIGGER IF EXISTS job_completion_audit_trigger ON job_completion_codes;
-- DROP TRIGGER IF EXISTS qr_code_verification_log ON job_completion_codes;


-- Step 3: Create proper mechanic activity logging (OPTIONAL - Future enhancement)
-- ----------------------------------------------------------------------------

-- Create mechanic_activity_logs table (if it doesn't exist)
CREATE TABLE IF NOT EXISTS mechanic_activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mechanic_id UUID NOT NULL REFERENCES service_providers(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL,  -- 'qr_verification', 'job_accepted', 'job_started', etc.
    target_type TEXT NOT NULL,  -- 'job_completion', 'service_request', etc.
    target_id UUID NOT NULL,    -- service_request_id
    action_details JSONB,       -- Additional details
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_mechanic_activity_logs_mechanic 
    ON mechanic_activity_logs(mechanic_id);
CREATE INDEX IF NOT EXISTS idx_mechanic_activity_logs_target 
    ON mechanic_activity_logs(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_mechanic_activity_logs_created 
    ON mechanic_activity_logs(created_at DESC);

-- Enable RLS
ALTER TABLE mechanic_activity_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Mechanics can view their own logs
CREATE POLICY mechanic_view_own_logs ON mechanic_activity_logs
    FOR SELECT
    USING (auth.uid() = mechanic_id);

-- RLS Policy: Admins can view all mechanic logs
CREATE POLICY admin_view_all_mechanic_logs ON mechanic_activity_logs
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid()
            AND user_type IN ('admin', 'super_admin')
        )
    );


-- Step 4: Create proper trigger for mechanic QR verification logging
-- ----------------------------------------------------------------------------

-- Function to log mechanic QR verification
CREATE OR REPLACE FUNCTION log_mechanic_qr_verification()
RETURNS TRIGGER AS $$
DECLARE
    mechanic_id UUID;
BEGIN
    -- Only log when QR code is marked as used
    IF NEW.is_used = true AND (OLD.is_used IS NULL OR OLD.is_used = false) THEN
        -- Get the mechanic_id from used_by_provider_id or assigned_mechanic_id
        SELECT 
            COALESCE(NEW.used_by_provider_id, sr.assigned_mechanic_id)
        INTO mechanic_id
        FROM service_requests sr
        WHERE sr.id = NEW.request_id;
        
        -- Insert into mechanic_activity_logs (not admin_activity_logs)
        IF mechanic_id IS NOT NULL THEN
            INSERT INTO mechanic_activity_logs (
                mechanic_id,
                action_type,
                target_type,
                target_id,
                action_details,
                created_at
            ) VALUES (
                mechanic_id,
                'qr_verification',
                'job_completion',
                NEW.request_id,
                jsonb_build_object(
                    'completion_code', NEW.completion_code,
                    'customer_id', NEW.customer_id,
                    'verified_at', NEW.used_at,
                    'verification_status', NEW.verification_status
                ),
                NOW()
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger (only if you want automatic logging)
-- DROP TRIGGER IF EXISTS log_mechanic_qr_verification_trigger ON job_completion_codes;
-- CREATE TRIGGER log_mechanic_qr_verification_trigger
--     AFTER UPDATE ON job_completion_codes
--     FOR EACH ROW
--     EXECUTE FUNCTION log_mechanic_qr_verification();


-- ============================================================================
-- QUICK FIX: Just disable the problematic trigger
-- ============================================================================
-- Run these queries to find and disable the trigger:

-- 1. Find triggers that reference admin_activity_logs
SELECT 
    t.trigger_name,
    t.event_object_table,
    t.action_statement,
    p.prosrc AS function_body
FROM information_schema.triggers t
LEFT JOIN pg_proc p ON p.proname = (
    SELECT proname FROM pg_proc 
    WHERE oid = (
        SELECT tgfoid FROM pg_trigger 
        WHERE tgname = t.trigger_name
    )
)
WHERE t.event_object_table = 'job_completion_codes'
  AND (
      p.prosrc LIKE '%admin_activity_logs%' 
      OR t.action_statement LIKE '%admin_activity_logs%'
  );

-- 2. After identifying the trigger name, drop it:
-- Replace 'trigger_name_here' with the actual trigger name from query above
-- DROP TRIGGER IF EXISTS trigger_name_here ON job_completion_codes;


-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check if trigger is disabled
SELECT 
    trigger_name,
    event_object_table,
    action_timing,
    event_manipulation
FROM information_schema.triggers
WHERE event_object_table = 'job_completion_codes';

-- Test QR code update without trigger error
-- UPDATE job_completion_codes
-- SET is_used = true,
--     used_at = NOW(),
--     verification_status = 'verified'
-- WHERE completion_code = 'BPOQYAUC-3899'
-- RETURNING *;

-- Check if update succeeded
SELECT 
    completion_code,
    is_used,
    used_at,
    verification_status
FROM job_completion_codes
WHERE completion_code = 'BPOQYAUC-3899';


-- ============================================================================
-- SUMMARY
-- ============================================================================
/*
PROBLEM: 
- Database trigger on job_completion_codes tries to insert into admin_activity_logs
- Mechanic QR scans have no admin_id → violates NOT NULL constraint
- QR verification fails

SOLUTION OPTIONS:
1. QUICK FIX (Recommended for now):
   - Drop the problematic trigger
   - Let app handle QR verification without automatic logging
   
2. PROPER FIX (Future):
   - Create mechanic_activity_logs table
   - Update trigger to log mechanic actions correctly
   - Keep admin_activity_logs only for admin actions

CURRENT STATUS:
- App has error handling to bypass trigger failures
- Manual fallback process updates tables directly
- QR scanning works but skips automatic logging
*/
