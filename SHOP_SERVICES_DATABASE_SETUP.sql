-- =====================================================
-- SHOP SERVICES - DATABASE SETUP & VERIFICATION
-- =====================================================
-- This script ensures the shop_services table is properly configured
-- for the Manage Services feature in the Talyer Owner portal

-- =====================================================
-- 1. VERIFY SHOP_SERVICES TABLE EXISTS AND HAS CORRECT STRUCTURE
-- =====================================================

-- Check if table exists
SELECT 
    table_name, 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'shop_services'
ORDER BY ordinal_position;

-- =====================================================
-- 2. ENSURE ALL REQUIRED COLUMNS EXIST
-- =====================================================

DO $$ 
BEGIN
    -- Add is_custom column if it doesn't exist (to track custom vs default services)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='shop_services' AND column_name='is_custom'
    ) THEN
        ALTER TABLE shop_services 
        ADD COLUMN is_custom BOOLEAN DEFAULT false;
        
        RAISE NOTICE 'Added is_custom column to shop_services';
    END IF;

    -- Ensure base_price has a default value
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='shop_services' 
        AND column_name='base_price'
        AND column_default IS NULL
    ) THEN
        ALTER TABLE shop_services 
        ALTER COLUMN base_price SET DEFAULT 0.00;
        
        RAISE NOTICE 'Set default value for base_price';
    END IF;

    -- Ensure is_active has a default value
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='shop_services' 
        AND column_name='is_active'
        AND column_default IS NULL
    ) THEN
        ALTER TABLE shop_services 
        ALTER COLUMN is_active SET DEFAULT true;
        
        RAISE NOTICE 'Set default value for is_active';
    END IF;

END $$;

-- =====================================================
-- 3. CREATE/UPDATE RLS POLICIES FOR SHOP SERVICES
-- =====================================================

-- Enable RLS if not already enabled
ALTER TABLE shop_services ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Shop owners can view their shop services" ON shop_services;
DROP POLICY IF EXISTS "Shop owners can insert their shop services" ON shop_services;
DROP POLICY IF EXISTS "Shop owners can update their shop services" ON shop_services;
DROP POLICY IF EXISTS "Shop owners can delete their shop services" ON shop_services;
DROP POLICY IF EXISTS "Customers can view active shop services" ON shop_services;

-- Policy: Shop owners can view their own shop's services
CREATE POLICY "Shop owners can view their shop services"
ON shop_services
FOR SELECT
TO authenticated
USING (
    shop_id IN (
        SELECT id FROM shops WHERE owner_id = auth.uid()
    )
);

-- Policy: Shop owners can insert services for their shop
CREATE POLICY "Shop owners can insert their shop services"
ON shop_services
FOR INSERT
TO authenticated
WITH CHECK (
    shop_id IN (
        SELECT id FROM shops WHERE owner_id = auth.uid()
    )
);

-- Policy: Shop owners can update their shop's services
CREATE POLICY "Shop owners can update their shop services"
ON shop_services
FOR UPDATE
TO authenticated
USING (
    shop_id IN (
        SELECT id FROM shops WHERE owner_id = auth.uid()
    )
)
WITH CHECK (
    shop_id IN (
        SELECT id FROM shops WHERE owner_id = auth.uid()
    )
);

-- Policy: Shop owners can delete their shop's services
CREATE POLICY "Shop owners can delete their shop services"
ON shop_services
FOR DELETE
TO authenticated
USING (
    shop_id IN (
        SELECT id FROM shops WHERE owner_id = auth.uid()
    )
);

-- Policy: Customers can view active services from all shops
CREATE POLICY "Customers can view active shop services"
ON shop_services
FOR SELECT
TO authenticated
USING (is_active = true);

-- =====================================================
-- 4. CREATE INDEXES FOR BETTER PERFORMANCE
-- =====================================================

-- Index on shop_id for faster queries
CREATE INDEX IF NOT EXISTS idx_shop_services_shop_id 
ON shop_services(shop_id);

-- Index on is_active for filtering
CREATE INDEX IF NOT EXISTS idx_shop_services_is_active 
ON shop_services(is_active);

-- Index on service_name for search
CREATE INDEX IF NOT EXISTS idx_shop_services_service_name 
ON shop_services(service_name);

-- Index on is_custom for filtering custom services
CREATE INDEX IF NOT EXISTS idx_shop_services_is_custom 
ON shop_services(is_custom);

-- Composite index for shop + active services
CREATE INDEX IF NOT EXISTS idx_shop_services_shop_active 
ON shop_services(shop_id, is_active);

-- =====================================================
-- 5. ADD HELPFUL COMMENTS TO COLUMNS
-- =====================================================

COMMENT ON COLUMN shop_services.service_name IS 'Name of the service (required)';
COMMENT ON COLUMN shop_services.description IS 'Description of what the service includes (optional)';
COMMENT ON COLUMN shop_services.base_price IS 'Price in Philippine Peso (required)';
COMMENT ON COLUMN shop_services.is_custom IS 'True if this is a custom service created by shop owner';
COMMENT ON COLUMN shop_services.is_active IS 'True if service is currently available for booking';
COMMENT ON COLUMN shop_services.shop_id IS 'Foreign key to shops table';
COMMENT ON COLUMN shop_services.category_id IS 'Foreign key to service_categories (nullable for custom services)';

-- =====================================================
-- 6. VERIFICATION QUERIES
-- =====================================================

-- Check RLS policies
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'shop_services'
ORDER BY policyname;

-- Check indexes
SELECT 
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'shop_services'
ORDER BY indexname;

-- =====================================================
-- 7. SAMPLE DATA VERIFICATION
-- =====================================================

-- Count total services per shop
SELECT 
    s.shop_name,
    COUNT(ss.id) as total_services,
    COUNT(CASE WHEN ss.is_custom THEN 1 END) as custom_services,
    COUNT(CASE WHEN ss.is_active THEN 1 END) as active_services
FROM shops s
LEFT JOIN shop_services ss ON s.id = ss.shop_id
GROUP BY s.id, s.shop_name
ORDER BY s.shop_name;

-- Show recent custom services
SELECT 
    ss.id,
    s.shop_name,
    ss.service_name,
    ss.description,
    ss.base_price,
    ss.is_custom,
    ss.is_active,
    ss.created_at
FROM shop_services ss
JOIN shops s ON ss.shop_id = s.id
WHERE ss.is_custom = true
ORDER BY ss.created_at DESC
LIMIT 10;

-- =====================================================
-- 8. HELPER FUNCTION - GET SHOP SERVICES FOR OWNER
-- =====================================================

CREATE OR REPLACE FUNCTION get_shop_services_for_owner(owner_user_id UUID)
RETURNS TABLE (
    service_id UUID,
    shop_id UUID,
    shop_name VARCHAR,
    service_name TEXT,
    description TEXT,
    base_price NUMERIC,
    is_custom BOOLEAN,
    is_active BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ss.id as service_id,
        ss.shop_id,
        s.shop_name,
        ss.service_name,
        ss.description,
        ss.base_price,
        ss.is_custom,
        ss.is_active,
        ss.created_at,
        ss.updated_at
    FROM shop_services ss
    JOIN shops s ON ss.shop_id = s.id
    WHERE s.owner_id = owner_user_id
    ORDER BY ss.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_shop_services_for_owner(UUID) TO authenticated;

-- =====================================================
-- 9. TESTING QUERIES
-- =====================================================

-- Test inserting a custom service (replace with actual shop_id)
-- INSERT INTO shop_services (
--     shop_id,
--     service_name,
--     description,
--     base_price,
--     is_custom,
--     is_active,
--     created_at,
--     updated_at
-- ) VALUES (
--     'YOUR_SHOP_ID_HERE',
--     'Custom Oil Change',
--     'Full synthetic oil change with filter replacement',
--     1500.00,
--     true,
--     true,
--     now(),
--     now()
-- );

-- Test updating a service (replace with actual service_id)
-- UPDATE shop_services 
-- SET 
--     service_name = 'Updated Service Name',
--     base_price = 2000.00,
--     updated_at = now()
-- WHERE id = 'YOUR_SERVICE_ID_HERE';

-- Test deleting a service (replace with actual service_id)
-- DELETE FROM shop_services WHERE id = 'YOUR_SERVICE_ID_HERE';

-- =====================================================
-- 10. TROUBLESHOOTING QUERIES
-- =====================================================

-- Check if a specific user can access shop services
-- Replace 'USER_ID_HERE' with actual user ID
-- SELECT 
--     ss.*,
--     s.shop_name,
--     s.owner_id
-- FROM shop_services ss
-- JOIN shops s ON ss.shop_id = s.id
-- WHERE s.owner_id = 'USER_ID_HERE';

-- Check for orphaned services (services without a shop)
SELECT 
    ss.id,
    ss.service_name,
    ss.shop_id
FROM shop_services ss
LEFT JOIN shops s ON ss.shop_id = s.id
WHERE s.id IS NULL;

-- Check for duplicate service names in same shop
SELECT 
    shop_id,
    service_name,
    COUNT(*) as duplicate_count
FROM shop_services
GROUP BY shop_id, service_name
HAVING COUNT(*) > 1;

-- =====================================================
-- END OF SCRIPT
-- =====================================================

COMMENT ON TABLE shop_services IS 'Stores services offered by repair shops - supports both default and custom services';

-- Display success message
DO $$ 
BEGIN
    RAISE NOTICE '✅ Shop Services database setup complete!';
    RAISE NOTICE '✅ RLS policies configured';
    RAISE NOTICE '✅ Indexes created for performance';
    RAISE NOTICE '✅ Helper functions added';
    RAISE NOTICE 'ℹ️  Shop owners can now manage their services via the app';
END $$;
