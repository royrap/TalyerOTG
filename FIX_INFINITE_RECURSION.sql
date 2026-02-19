-- ========================================
-- 🔧 FIX INFINITE RECURSION - SAFE APPROACH
-- ========================================
-- The previous policy caused infinite recursion because:
-- 1. user_profiles policy checks service_requests
-- 2. service_requests policy checks user_profiles
-- 3. This creates a circular dependency!
--
-- Solution: Use a SECURITY DEFINER function that bypasses RLS

-- Step 1: Drop the problematic policy
DROP POLICY IF EXISTS "mechanics_view_assigned_customers" ON user_profiles;

-- Step 2: Create a SECURITY DEFINER function to safely check relationships
CREATE OR REPLACE FUNCTION public.is_mechanic_serving_customer(
  p_customer_id uuid,
  p_mechanic_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER  -- This bypasses RLS!
SET search_path = public
AS $$
BEGIN
  -- Check if there's an active service request connecting them
  RETURN EXISTS (
    SELECT 1 
    FROM service_requests 
    WHERE customer_id = p_customer_id 
      AND assigned_mechanic_id = p_mechanic_id
      AND status NOT IN ('cancelled', 'completed')  -- Only active requests
  );
END;
$$;

-- Step 3: Add TWO-WAY policy using the safe function
CREATE POLICY "mechanics_and_customers_view_each_other"
ON user_profiles
FOR SELECT
TO public
USING (
  -- Mechanics can view customers they're serving
  is_mechanic_serving_customer(id, auth.uid())
  OR
  -- Customers can view mechanics serving them
  is_mechanic_serving_customer(auth.uid(), id)
);

-- ========================================
-- 📊 VERIFICATION
-- ========================================
SELECT 
    policyname,
    cmd as command
FROM pg_policies
WHERE tablename = 'user_profiles' 
  AND policyname = 'mechanics_and_customers_view_each_other';

DO $$
BEGIN
    RAISE NOTICE '✅ TWO-WAY policy added using SECURITY DEFINER function!';
    RAISE NOTICE '👥 Mechanics can see customers AND customers can see mechanics!';
    RAISE NOTICE '📌 This avoids infinite recursion by bypassing RLS in the function.';
END $$;
