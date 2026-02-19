-- ========================================
-- 🔧 FIX CURRENT ERRORS (Priority)
-- ========================================

-- ERROR 1: Missing last_active_at column
-- The code is trying to UPDATE this column but it doesn't exist
-- We need to ADD it (not DROP it)

ALTER TABLE mechanic_availability_status 
ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ DEFAULT NOW();

-- Update existing records
UPDATE mechanic_availability_status 
SET last_active_at = NOW() 
WHERE last_active_at IS NULL;

-- ========================================
-- VERIFY FIXES
-- ========================================

-- Check if column exists now
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'mechanic_availability_status' 
AND column_name = 'last_active_at';

-- Check all mechanic_availability_status columns
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'mechanic_availability_status' 
ORDER BY ordinal_position;

-- ========================================
-- SUCCESS MESSAGE
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ FIXES APPLIED!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Added column:';
    RAISE NOTICE '  - mechanic_availability_status.last_active_at';
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;
