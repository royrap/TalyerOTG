-- =====================================================
-- QUICK CONNECTION FIXES
-- =====================================================
-- Run these if validation shows missing connections

-- Fix 1: Connect mechanics to shops based on invitations
INSERT INTO shop_mechanics (
    shop_id,
    mechanic_id,
    role,
    is_active,
    is_available,
    joined_at,
    created_at,
    updated_at
)
SELECT DISTINCT
    mi.shop_id,
    mi.mechanic_user_id,
    'mechanic',
    true,
    true,
    COALESCE(mi.accepted_at, NOW()),
    NOW(),
    NOW()
FROM mechanic_invitations mi
JOIN user_profiles up ON up.id = mi.mechanic_user_id
WHERE mi.status = 'accepted' 
AND mi.mechanic_user_id IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM shop_mechanics sm 
    WHERE sm.shop_id = mi.shop_id 
    AND sm.mechanic_id = mi.mechanic_user_id
);

-- Fix 2: Update user_profiles with shop connections
UPDATE user_profiles up
SET shop_id = sm.shop_id,
    updated_at = NOW()
FROM shop_mechanics sm
WHERE sm.mechanic_id = up.id 
AND up.user_type = 'mechanic'
AND (up.shop_id IS NULL OR up.shop_id != sm.shop_id)
AND sm.is_active = true;

-- Fix 3: Create customer-mechanic connections
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
    sr.id,
    sr.customer_id,
    s.owner_id,
    sp.id,
    CASE 
        WHEN sr.status IN ('completed', 'cancelled') THEN 'completed'
        WHEN sr.status IN ('assigned', 'in_progress', 'inspection_completed', 'invoice_sent', 'invoice_paid') THEN 'connected'
        ELSE 'pending'
    END,
    'service_request',
    sr.created_at,
    sr.assigned_at,
    GREATEST(sr.updated_at, NOW())
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

-- Validation: Check results
SELECT 'AFTER FIXES - CONNECTION COUNTS:' as status;
SELECT 
    'Mechanic-Shop Connections' as connection_type,
    COUNT(*) as count
FROM shop_mechanics sm
JOIN user_profiles up ON up.id = sm.mechanic_id
WHERE sm.is_active = true AND up.user_type = 'mechanic'

UNION ALL

SELECT 
    'Customer-Mechanic Connections' as connection_type,
    COUNT(*) as count
FROM talyer_customer_connections
WHERE status IN ('connected', 'completed');
