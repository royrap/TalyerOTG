-- =====================================================
-- MECHANIC-SHOP AND CUSTOMER-MECHANIC CONNECTION FIXES
-- =====================================================
-- Ensures proper connections:
-- 1. Mechanics connected to shops that added them
-- 2. Customers connected to mechanics who accepted their requests
-- =====================================================

BEGIN;

-- =====================================================
-- PART 1: FIX MECHANIC-SHOP CONNECTIONS
-- =====================================================

-- Ensure all mechanics who were added via invitations have proper shop connections
DO $$
DECLARE
    v_invitation_record RECORD;
    v_shop_mechanic_exists boolean;
BEGIN
    RAISE NOTICE '🔧 FIXING MECHANIC-SHOP CONNECTIONS...';
    
    -- Loop through all accepted mechanic invitations that don't have shop_mechanic entries
    FOR v_invitation_record IN
        SELECT DISTINCT
            mi.shop_id,
            mi.mechanic_user_id as mechanic_id,
            mi.shop_owner_id,
            s.shop_name,
            up.first_name,
            up.last_name,
            up.email
        FROM mechanic_invitations mi
        JOIN shops s ON s.id = mi.shop_id
        JOIN user_profiles up ON up.id = mi.mechanic_user_id
        WHERE mi.status = 'accepted' 
        AND mi.mechanic_user_id IS NOT NULL
    LOOP
        -- Check if shop_mechanic entry exists
        SELECT EXISTS(
            SELECT 1 FROM shop_mechanics 
            WHERE shop_id = v_invitation_record.shop_id 
            AND mechanic_id = v_invitation_record.mechanic_id
        ) INTO v_shop_mechanic_exists;
        
        IF NOT v_shop_mechanic_exists THEN
            -- Create the shop_mechanic connection
            INSERT INTO shop_mechanics (
                shop_id,
                mechanic_id,
                role,
                is_active,
                is_available,
                joined_at,
                created_at,
                updated_at
            ) VALUES (
                v_invitation_record.shop_id,
                v_invitation_record.mechanic_id,
                'mechanic',
                true,
                true,
                NOW(),
                NOW(),
                NOW()
            );
            
            RAISE NOTICE '✅ Connected mechanic % % to shop %', 
                v_invitation_record.first_name, 
                v_invitation_record.last_name,
                v_invitation_record.shop_name;
        END IF;
    END LOOP;
END $$;

-- Update user_profiles.shop_id for mechanics who should be connected to shops
UPDATE user_profiles up
SET shop_id = sm.shop_id,
    updated_at = NOW()
FROM shop_mechanics sm
WHERE sm.mechanic_id = up.id 
AND up.user_type = 'mechanic'
AND (up.shop_id IS NULL OR up.shop_id != sm.shop_id)
AND sm.is_active = true;

-- Ensure service_providers have proper talyer_owner_id connections
UPDATE service_providers sp
SET talyer_owner_id = s.owner_id,
    updated_at = NOW()
FROM user_profiles up
JOIN shop_mechanics sm ON sm.mechanic_id = up.id
JOIN shops s ON s.id = sm.shop_id
WHERE sp.user_id = up.id
AND up.user_type = 'mechanic'
AND (sp.talyer_owner_id IS NULL OR sp.talyer_owner_id != s.owner_id)
AND sm.is_active = true;

-- =====================================================
-- PART 2: FIX CUSTOMER-MECHANIC CONNECTIONS
-- =====================================================

-- Ensure talyer_customer_connections exist for all service requests with assigned mechanics
INSERT INTO talyer_customer_connections (
    service_request_id,
    customer_id,
    talyer_owner_id,
    provider_id,
    status,
    connection_type,
    created_at,
    connected_at,
    last_activity
)
SELECT DISTINCT
    sr.id as service_request_id,
    sr.customer_id,
    s.owner_id as talyer_owner_id,
    sp.id as provider_id,
    CASE 
        WHEN sr.status IN ('completed', 'cancelled') THEN 'completed'
        WHEN sr.status IN ('assigned', 'in_progress', 'inspection_completed', 'invoice_sent', 'invoice_paid') THEN 'connected'
        ELSE 'pending'
    END as status,
    'service_request' as connection_type,
    sr.created_at,
    sr.assigned_at,
    GREATEST(sr.updated_at, NOW()) as last_activity
FROM service_requests sr
JOIN user_profiles up ON up.id = sr.assigned_mechanic_id
JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
JOIN shops s ON s.id = sm.shop_id
JOIN service_providers sp ON sp.user_id = up.id
WHERE sr.assigned_mechanic_id IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM talyer_customer_connections tcc
    WHERE tcc.service_request_id = sr.id
);

-- Update existing connections with proper details
UPDATE talyer_customer_connections tcc
SET 
    customer_details = jsonb_build_object(
        'customer_id', c.id,
        'name', c.first_name || ' ' || c.last_name,
        'email', c.email,
        'phone', c.phone_number
    ),
    talyer_details = jsonb_build_object(
        'talyer_owner_id', talyer_owner.id,
        'name', talyer_owner.first_name || ' ' || talyer_owner.last_name,
        'email', talyer_owner.email,
        'shop_id', s.id,
        'shop_name', s.shop_name
    ),
    last_activity = NOW()
FROM service_requests sr
JOIN user_profiles c ON c.id = sr.customer_id
JOIN user_profiles talyer_owner ON talyer_owner.id = tcc.talyer_owner_id
JOIN shops s ON s.owner_id = talyer_owner.id
WHERE tcc.service_request_id = sr.id
AND (tcc.customer_details IS NULL OR tcc.talyer_details IS NULL);

-- =====================================================
-- PART 3: VALIDATION AND CLEANUP
-- =====================================================

-- Remove orphaned shop_mechanics entries (mechanics that don't exist)
DELETE FROM shop_mechanics sm
WHERE NOT EXISTS (
    SELECT 1 FROM user_profiles up 
    WHERE up.id = sm.mechanic_id 
    AND up.user_type = 'mechanic'
);

-- Remove orphaned shop_mechanics entries (shops that don't exist)
DELETE FROM shop_mechanics sm
WHERE NOT EXISTS (
    SELECT 1 FROM shops s 
    WHERE s.id = sm.shop_id 
    AND s.is_active = true
);

-- Fix any service_providers without proper shop connections
UPDATE service_providers sp
SET shop_id = sm.shop_id,
    updated_at = NOW()
FROM user_profiles up
JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
WHERE sp.user_id = up.id
AND up.user_type = 'mechanic'
AND (sp.shop_id IS NULL OR sp.shop_id != sm.shop_id);

-- Update mechanic_availability_status with proper shop connections
INSERT INTO mechanic_availability_status (
    mechanic_id,
    shop_id,
    current_status,
    is_accepting_requests,
    created_at,
    updated_at
)
SELECT 
    sm.mechanic_id,
    sm.shop_id,
    'available',
    sm.is_available,
    NOW(),
    NOW()
FROM shop_mechanics sm
JOIN user_profiles up ON up.id = sm.mechanic_id
WHERE sm.is_active = true
AND up.user_type = 'mechanic'
ON CONFLICT (mechanic_id) DO UPDATE SET
    shop_id = EXCLUDED.shop_id,
    updated_at = NOW();

-- =====================================================
-- PART 4: CREATE MISSING CONNECTIONS REPORT
-- =====================================================

-- Report on connections created
DO $$
DECLARE
    v_shop_connections_count integer;
    v_customer_connections_count integer;
    v_orphaned_mechanics integer;
BEGIN
    -- Count shop connections
    SELECT COUNT(*) INTO v_shop_connections_count
    FROM shop_mechanics sm
    JOIN user_profiles up ON up.id = sm.mechanic_id
    WHERE sm.is_active = true AND up.user_type = 'mechanic';
    
    -- Count customer connections
    SELECT COUNT(*) INTO v_customer_connections_count
    FROM talyer_customer_connections
    WHERE status IN ('connected', 'completed');
    
    -- Count mechanics without shops
    SELECT COUNT(*) INTO v_orphaned_mechanics
    FROM user_profiles up
    LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
    WHERE up.user_type = 'mechanic' AND sm.id IS NULL;
    
    RAISE NOTICE '';
    RAISE NOTICE '🎯 CONNECTION REPAIR SUMMARY:';
    RAISE NOTICE '✅ Shop-Mechanic Connections: %', v_shop_connections_count;
    RAISE NOTICE '✅ Customer-Mechanic Connections: %', v_customer_connections_count;
    RAISE NOTICE '⚠️ Orphaned Mechanics: %', v_orphaned_mechanics;
    RAISE NOTICE '';
END $$;

-- =====================================================
-- PART 5: CREATE VALIDATION VIEWS
-- =====================================================

-- Create view for mechanic-shop connections
CREATE OR REPLACE VIEW v_mechanic_shop_connections AS
SELECT 
    up.id as mechanic_id,
    up.first_name || ' ' || up.last_name as mechanic_name,
    up.email as mechanic_email,
    s.id as shop_id,
    s.shop_name,
    shop_owner.first_name || ' ' || shop_owner.last_name as shop_owner_name,
    shop_owner.email as shop_owner_email,
    sm.role as mechanic_role,
    sm.is_active,
    sm.is_available,
    sm.joined_at,
    sp.id as service_provider_id,
    sp.talyer_owner_id
FROM user_profiles up
JOIN shop_mechanics sm ON sm.mechanic_id = up.id
JOIN shops s ON s.id = sm.shop_id
JOIN user_profiles shop_owner ON shop_owner.id = s.owner_id
LEFT JOIN service_providers sp ON sp.user_id = up.id
WHERE up.user_type = 'mechanic' AND sm.is_active = true;

-- Create view for customer-mechanic connections
CREATE OR REPLACE VIEW v_customer_mechanic_connections AS
SELECT 
    sr.id as request_id,
    sr.title as service_title,
    customer.first_name || ' ' || customer.last_name as customer_name,
    customer.email as customer_email,
    mechanic.first_name || ' ' || mechanic.last_name as mechanic_name,
    mechanic.email as mechanic_email,
    owner.first_name || ' ' || owner.last_name as shop_owner_name,
    s.shop_name,
    sr.status as request_status,
    sr.created_at as request_created,
    sr.assigned_at,
    tcc.status as connection_status,
    tcc.connected_at
FROM service_requests sr
JOIN user_profiles customer ON customer.id = sr.customer_id
LEFT JOIN user_profiles mechanic ON mechanic.id = sr.assigned_mechanic_id
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = mechanic.id AND sm.is_active = true
LEFT JOIN shops s ON s.id = sm.shop_id
LEFT JOIN user_profiles owner ON owner.id = s.owner_id
LEFT JOIN talyer_customer_connections tcc ON tcc.service_request_id = sr.id
ORDER BY sr.created_at DESC;

COMMIT;

-- Final completion message
DO $$
BEGIN
    RAISE NOTICE '🎉 MECHANIC-CUSTOMER CONNECTION FIXES COMPLETED!';
    RAISE NOTICE 'Use these views to validate connections:';
    RAISE NOTICE '- SELECT * FROM v_mechanic_shop_connections;';
    RAISE NOTICE '- SELECT * FROM v_customer_mechanic_connections;';
END $$;