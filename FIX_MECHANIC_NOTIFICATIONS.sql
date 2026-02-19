-- ========================================
-- FIX MECHANIC NOTIFICATION SYSTEM
-- ========================================

-- 1. ADD MISSING COLUMN TO mechanic_availability_status
ALTER TABLE mechanic_availability_status 
ADD COLUMN IF NOT EXISTS last_active_at timestamp with time zone DEFAULT now();

-- Update existing records
UPDATE mechanic_availability_status 
SET last_active_at = last_status_update 
WHERE last_active_at IS NULL;

-- 2. CREATE INDEX for better performance
CREATE INDEX IF NOT EXISTS idx_mechanic_availability_last_active 
ON mechanic_availability_status(last_active_at);

-- ========================================
-- SUCCESS MESSAGE
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ MECHANIC NOTIFICATION SYSTEM FIXED!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Fixed:';
    RAISE NOTICE '  1. Added last_active_at column';
    RAISE NOTICE '  2. Updated existing records';
    RAISE NOTICE '  3. Created performance index';
    RAISE NOTICE '';
    RAISE NOTICE 'Mechanics should now receive notifications!';
    RAISE NOTICE '========================================';
END $$;
