-- ========================================
-- FIX MECHANIC STATUS CONSTRAINT ERROR
-- ========================================

-- Check current constraint
SELECT conname, pg_get_constraintdef(oid) 
FROM pg_constraint 
WHERE conrelid = 'mechanic_availability_status'::regclass 
AND conname LIKE '%status_check%';

-- Drop the problematic constraint if it's too restrictive
ALTER TABLE mechanic_availability_status 
DROP CONSTRAINT IF EXISTS mechanic_availability_status_current_status_check;

-- Add new constraint with correct allowed values
ALTER TABLE mechanic_availability_status
ADD CONSTRAINT mechanic_availability_status_current_status_check 
CHECK (current_status IN ('available', 'busy', 'offline', 'on_break', 'in_service'));

-- ========================================
-- VERIFY FIX
-- ========================================

-- Check all mechanics' current status values
SELECT 
    mechanic_id,
    current_status,
    is_accepting_requests,
    last_status_update
FROM mechanic_availability_status
ORDER BY last_status_update DESC;

-- ========================================
-- SUCCESS MESSAGE
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ MECHANIC STATUS CONSTRAINT FIXED!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Fixed:';
    RAISE NOTICE '  1. Removed old restrictive constraint';
    RAISE NOTICE '  2. Added correct status values';
    RAISE NOTICE '  3. Allowed statuses: available, busy, offline, on_break, in_service';
    RAISE NOTICE '';
    RAISE NOTICE 'Mechanics can now accept requests!';
    RAISE NOTICE '========================================';
END $$;
