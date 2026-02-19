-- =====================================================
-- CONNECTION INTEGRITY CONSTRAINTS AND TRIGGERS
-- =====================================================
-- Ensures proper relationships are maintained automatically
-- =====================================================

-- =====================================================
-- TRIGGERS TO MAINTAIN SHOP-MECHANIC CONNECTIONS
-- =====================================================

-- Function to ensure mechanic invitation creates shop_mechanic entry
CREATE OR REPLACE FUNCTION ensure_mechanic_shop_connection()
RETURNS TRIGGER AS $$
BEGIN
    -- When a mechanic invitation is accepted, ensure shop_mechanic entry exists
    IF NEW.status = 'accepted' AND NEW.mechanic_user_id IS NOT NULL THEN
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
            NEW.shop_id,
            NEW.mechanic_user_id,
            'mechanic',
            true,
            true,
            NEW.accepted_at,
            NOW(),
            NOW()
        )
        ON CONFLICT (shop_id, mechanic_id) DO UPDATE SET
            is_active = true,
            updated_at = NOW();
            
        -- Update user_profiles with shop connection
        UPDATE user_profiles 
        SET shop_id = NEW.shop_id,
            updated_at = NOW()
        WHERE id = NEW.mechanic_user_id;
        
        -- Update service_providers with talyer_owner connection
        UPDATE service_providers sp
        SET talyer_owner_id = s.owner_id,
            shop_id = NEW.shop_id,
            updated_at = NOW()
        FROM shops s
        WHERE s.id = NEW.shop_id
        AND sp.user_id = NEW.mechanic_user_id;
        
        RAISE NOTICE '✅ Auto-connected mechanic % to shop %', NEW.mechanic_user_id, NEW.shop_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for mechanic invitations
DROP TRIGGER IF EXISTS trg_mechanic_invitation_accepted ON mechanic_invitations;
CREATE TRIGGER trg_mechanic_invitation_accepted
    AFTER UPDATE ON mechanic_invitations
    FOR EACH ROW
    WHEN (OLD.status != 'accepted' AND NEW.status = 'accepted')
    EXECUTE FUNCTION ensure_mechanic_shop_connection();

-- =====================================================
-- TRIGGERS TO MAINTAIN CUSTOMER-MECHANIC CONNECTIONS
-- =====================================================

-- Function to create talyer_customer_connection when mechanic is assigned
CREATE OR REPLACE FUNCTION ensure_customer_mechanic_connection()
RETURNS TRIGGER AS $$
DECLARE
    v_talyer_owner_id uuid;
    v_service_provider_id uuid;
BEGIN
    -- When a mechanic is assigned to a service request
    IF NEW.assigned_mechanic_id IS NOT NULL AND (OLD.assigned_mechanic_id IS NULL OR OLD.assigned_mechanic_id != NEW.assigned_mechanic_id) THEN
        
        -- Get talyer owner and service provider info
        SELECT s.owner_id, sp.id
        INTO v_talyer_owner_id, v_service_provider_id
        FROM user_profiles up
        LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
        LEFT JOIN shops s ON s.id = sm.shop_id
        LEFT JOIN service_providers sp ON sp.user_id = up.id
        WHERE up.id = NEW.assigned_mechanic_id
        LIMIT 1;
        
        -- Create or update talyer_customer_connection
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
        ) VALUES (
            NEW.id,
            NEW.customer_id,
            v_talyer_owner_id,
            v_service_provider_id,
            'connected',
            'service_request',
            NOW(),
            NOW(),
            NOW()
        )
        ON CONFLICT (service_request_id) DO UPDATE SET
            talyer_owner_id = v_talyer_owner_id,
            provider_id = v_service_provider_id,
            status = 'connected',
            connected_at = NOW(),
            last_activity = NOW();
            
        RAISE NOTICE '✅ Auto-connected customer % to mechanic % via talyer %', NEW.customer_id, NEW.assigned_mechanic_id, v_talyer_owner_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for service request assignments
DROP TRIGGER IF EXISTS trg_service_request_mechanic_assigned ON service_requests;
CREATE TRIGGER trg_service_request_mechanic_assigned
    AFTER UPDATE ON service_requests
    FOR EACH ROW
    WHEN (NEW.assigned_mechanic_id IS NOT NULL)
    EXECUTE FUNCTION ensure_customer_mechanic_connection();

-- =====================================================
-- FUNCTION TO VALIDATE CONNECTION INTEGRITY
-- =====================================================

CREATE OR REPLACE FUNCTION validate_connection_integrity()
RETURNS TABLE (
    check_type text,
    status text,
    count_found integer,
    details text
) AS $$
BEGIN
    -- Check 1: Mechanics without shop connections
    RETURN QUERY
    SELECT 
        'Orphaned Mechanics'::text,
        CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END::text,
        COUNT(*)::integer,
        'Mechanics without shop_mechanics entries'::text
    FROM user_profiles up
    LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
    WHERE up.user_type = 'mechanic' AND sm.id IS NULL;
    
    -- Check 2: Service requests without customer connections
    RETURN QUERY
    SELECT 
        'Missing Customer Connections'::text,
        CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END::text,
        COUNT(*)::integer,
        'Service requests with assigned mechanics but no talyer_customer_connections'::text
    FROM service_requests sr
    WHERE sr.assigned_mechanic_id IS NOT NULL
    AND NOT EXISTS (
        SELECT 1 FROM talyer_customer_connections tcc 
        WHERE tcc.service_request_id = sr.id
    );
    
    -- Check 3: Shop mechanics without service providers
    RETURN QUERY
    SELECT 
        'Shop Mechanics Missing Service Providers'::text,
        CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END::text,
        COUNT(*)::integer,
        'Mechanics in shop_mechanics without corresponding service_providers entries'::text
    FROM shop_mechanics sm
    JOIN user_profiles up ON up.id = sm.mechanic_id
    LEFT JOIN service_providers sp ON sp.user_id = up.id
    WHERE sm.is_active = true AND up.user_type = 'mechanic' AND sp.id IS NULL;
    
    -- Check 4: Service providers without talyer owners
    RETURN QUERY
    SELECT 
        'Service Providers Missing Talyer Owners'::text,
        CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END::text,
        COUNT(*)::integer,
        'Service providers for mechanics without talyer_owner_id set'::text
    FROM service_providers sp
    JOIN user_profiles up ON up.id = sp.user_id
    WHERE up.user_type = 'mechanic' AND sp.talyer_owner_id IS NULL;
    
    -- Summary check
    RETURN QUERY
    SELECT 
        'Overall Status'::text,
        CASE WHEN NOT EXISTS (
            SELECT 1 FROM user_profiles up
            LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
            WHERE up.user_type = 'mechanic' AND sm.id IS NULL
            UNION ALL
            SELECT 1 FROM service_requests sr
            WHERE sr.assigned_mechanic_id IS NOT NULL
            AND NOT EXISTS (SELECT 1 FROM talyer_customer_connections tcc WHERE tcc.service_request_id = sr.id)
        ) THEN '🎉 ALL CONNECTIONS VALID' ELSE '⚠️ ISSUES FOUND' END::text,
        0::integer,
        'Run individual checks above for details'::text;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- MAINTENANCE FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION repair_missing_connections()
RETURNS void AS $$
BEGIN
    -- Repair shop-mechanic connections from invitations
    INSERT INTO shop_mechanics (shop_id, mechanic_id, role, is_active, is_available, joined_at, created_at, updated_at)
    SELECT DISTINCT
        mi.shop_id,
        mi.mechanic_user_id,
        'mechanic',
        true,
        true,
        mi.accepted_at,
        NOW(),
        NOW()
    FROM mechanic_invitations mi
    WHERE mi.status = 'accepted' 
    AND mi.mechanic_user_id IS NOT NULL
    AND NOT EXISTS (
        SELECT 1 FROM shop_mechanics sm 
        WHERE sm.shop_id = mi.shop_id AND sm.mechanic_id = mi.mechanic_user_id
    );
    
    -- Repair customer-mechanic connections from service requests
    INSERT INTO talyer_customer_connections (service_request_id, customer_id, talyer_owner_id, provider_id, status, connection_type, created_at, connected_at, last_activity)
    SELECT 
        sr.id,
        sr.customer_id,
        s.owner_id,
        sp.id,
        CASE 
            WHEN sr.status IN ('completed', 'cancelled') THEN 'completed'
            WHEN sr.status IN ('assigned', 'in_progress') THEN 'connected'
            ELSE 'pending'
        END,
        'service_request',
        sr.created_at,
        sr.assigned_at,
        NOW()
    FROM service_requests sr
    JOIN user_profiles up ON up.id = sr.assigned_mechanic_id
    JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
    JOIN shops s ON s.id = sm.shop_id
    JOIN service_providers sp ON sp.user_id = up.id
    WHERE sr.assigned_mechanic_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM talyer_customer_connections tcc WHERE tcc.service_request_id = sr.id);
    
    RAISE NOTICE '🔧 Connection repair completed';
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- CREATE CONSTRAINTS (IF NOT EXISTS)
-- =====================================================

-- Ensure shop_mechanics has unique constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'shop_mechanics_shop_id_mechanic_id_key'
    ) THEN
        ALTER TABLE shop_mechanics 
        ADD CONSTRAINT shop_mechanics_shop_id_mechanic_id_key 
        UNIQUE (shop_id, mechanic_id);
    END IF;
END $$;

-- Ensure talyer_customer_connections has unique constraint on service_request_id
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'talyer_customer_connections_service_request_id_key'
    ) THEN
        ALTER TABLE talyer_customer_connections 
        ADD CONSTRAINT talyer_customer_connections_service_request_id_key 
        UNIQUE (service_request_id);
    END IF;
END $$;

-- Final completion message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎯 CONNECTION INTEGRITY SYSTEM INSTALLED!';
    RAISE NOTICE '';
    RAISE NOTICE 'Available functions:';
    RAISE NOTICE '- SELECT * FROM validate_connection_integrity();';
    RAISE NOTICE '- SELECT repair_missing_connections();';
    RAISE NOTICE '';
    RAISE NOTICE 'Auto-triggers enabled for:';
    RAISE NOTICE '✅ mechanic_invitations -> shop_mechanics';
    RAISE NOTICE '✅ service_requests -> talyer_customer_connections';
END $$;