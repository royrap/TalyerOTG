-- ========================================
-- 🔧 ADD MECHANIC-TO-CUSTOMER VIEW POLICY
-- ========================================
-- This allows mechanics to view customer profiles when they have active service requests together
-- SAFE: Does not touch existing policies, just adds a new SELECT policy

-- Add policy for mechanics to view customers they're serving
CREATE POLICY "mechanics_view_assigned_customers"
ON user_profiles
FOR SELECT
TO public
USING (
  -- Allow viewing if there's an active service request connecting them
  EXISTS (
    SELECT 1 
    FROM service_requests 
    WHERE customer_id = user_profiles.id 
      AND assigned_mechanic_id = auth.uid()
  )
);

-- ========================================
-- 📊 VERIFICATION
-- ========================================
-- Check that the new policy was created
SELECT 
    policyname,
    cmd as command,
    qual as using_expression
FROM pg_policies
WHERE tablename = 'user_profiles' 
  AND policyname = 'mechanics_view_assigned_customers';

-- Count total policies on user_profiles (should be 5 now)
SELECT COUNT(*) as total_policies
FROM pg_policies
WHERE tablename = 'user_profiles';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Policy added! Mechanics can now view customers they are serving.';
    RAISE NOTICE '⚠️  Remember: This is in ADDITION to existing policies, not a replacement.';
END $$;
