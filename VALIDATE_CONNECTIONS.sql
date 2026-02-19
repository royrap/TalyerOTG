-- =====================================================
-- MECHANIC-SHOP CONNECTION VALIDATION
-- =====================================================
-- Run this to check all mechanic-shop connections

SELECT 'MECHANIC-SHOP CONNECTIONS' as check_type;
SELECT 
    COUNT(*) as total_mechanics,
    COUNT(CASE WHEN up.shop_id IS NOT NULL THEN 1 END) as mechanics_with_shop,
    COUNT(CASE WHEN sm.id IS NOT NULL THEN 1 END) as mechanics_with_shop_mechanic_entry
FROM user_profiles up
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
WHERE up.user_type = 'mechanic';

-- Show mechanics without shop connections (these need fixing)
SELECT 'ORPHANED MECHANICS (NEED FIXING):' as status;
SELECT 
    up.id as mechanic_id,
    up.first_name || ' ' || up.last_name as mechanic_name,
    up.email,
    up.shop_id,
    'Missing shop_mechanics entry' as issue
FROM user_profiles up
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
WHERE up.user_type = 'mechanic' 
AND sm.id IS NULL;

-- =====================================================
-- CUSTOMER-MECHANIC CONNECTION VALIDATION  
-- =====================================================
-- Run this to check all customer-mechanic connections

SELECT 'CUSTOMER-MECHANIC CONNECTIONS' as check_type;
SELECT 
    COUNT(*) as total_service_requests,
    COUNT(CASE WHEN sr.assigned_mechanic_id IS NOT NULL THEN 1 END) as requests_with_mechanic,
    COUNT(CASE WHEN tcc.id IS NOT NULL THEN 1 END) as requests_with_connection_entry
FROM service_requests sr
LEFT JOIN talyer_customer_connections tcc ON tcc.service_request_id = sr.id;

-- Show service requests without proper connections (these need fixing)
SELECT 'MISSING CUSTOMER-MECHANIC CONNECTIONS:' as status;
SELECT 
    sr.id as request_id,
    sr.title,
    customer.first_name || ' ' || customer.last_name as customer_name,
    mechanic.first_name || ' ' || mechanic.last_name as mechanic_name,
    sr.status as request_status,
    'Missing talyer_customer_connections entry' as issue
FROM service_requests sr
JOIN user_profiles customer ON customer.id = sr.customer_id
LEFT JOIN user_profiles mechanic ON mechanic.id = sr.assigned_mechanic_id
LEFT JOIN talyer_customer_connections tcc ON tcc.service_request_id = sr.id
WHERE sr.assigned_mechanic_id IS NOT NULL 
AND tcc.id IS NULL;

-- =====================================================
-- TRIGGER FUNCTION VALIDATION
-- =====================================================
-- Check if trigger functions exist

SELECT 'TRIGGER FUNCTIONS STATUS:' as status;
SELECT 
    p.proname as function_name,
    CASE WHEN p.proname IS NOT NULL THEN 'âœ… EXISTS' ELSE 'âŒ MISSING' END as status
FROM (VALUES 
    ('ensure_mechanic_shop_connection'),
    ('ensure_customer_mechanic_connection'),
    ('validate_connection_integrity')
) AS expected_functions(fname)
LEFT JOIN pg_proc p ON p.proname = expected_functions.fname;

-- Check if triggers exist
SELECT 'TRIGGERS STATUS:' as status;
SELECT 
    t.tgname as trigger_name,
    c.relname as table_name,
    CASE WHEN t.tgname IS NOT NULL THEN 'âœ… EXISTS' ELSE 'âŒ MISSING' END as status
FROM (VALUES 
    ('trg_mechanic_invitation_accepted', 'mechanic_invitations'),
    ('trg_service_request_mechanic_assigned', 'service_requests')
) AS expected_triggers(tname, tablename)
LEFT JOIN pg_trigger t ON t.tgname = expected_triggers.tname
LEFT JOIN pg_class c ON c.oid = t.tgrelid AND c.relname = expected_triggers.tablename;

-- =====================================================
-- VIEW VALIDATION
-- =====================================================
-- Check if views exist and work

SELECT 'SYSTEM VIEWS STATUS:' as status;
SELECT 
    v.viewname,
    CASE WHEN v.viewname IS NOT NULL THEN 'âœ… EXISTS' ELSE 'âŒ MISSING' END as status
FROM (VALUES 
    ('v_mechanic_shop_connections'),
    ('v_customer_mechanic_connections')
) AS expected_views(vname)
LEFT JOIN pg_views v ON v.viewname = expected_views.vname;

-- Test the views (limit results for performance)
SELECT 'MECHANIC-SHOP CONNECTIONS SAMPLE:' as status;
SELECT * FROM v_mechanic_shop_connections LIMIT 5;

SELECT 'CUSTOMER-MECHANIC CONNECTIONS SAMPLE:' as status;
SELECT * FROM v_customer_mechanic_connections LIMIT 5;

-- =====================================================
-- SYSTEM HEALTH SUMMARY
-- =====================================================
-- Run validation function if it exists
SELECT * FROM validate_connection_integrity();
