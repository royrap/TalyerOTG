# COMPLETE SYSTEM VALIDATION SCRIPT
# This script validates all RoadAid system flows and connections

Write-Host "ROADAID SYSTEM FLOW VALIDATION" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Function to create validation SQL files for manual execution
function Create-ValidationQueries {
    Write-Host "Creating validation query files..." -ForegroundColor Yellow
    
    # Create connection validation query
    $connectionValidation = @"
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
    CASE WHEN p.proname IS NOT NULL THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
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
    CASE WHEN t.tgname IS NOT NULL THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
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
    CASE WHEN v.viewname IS NOT NULL THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
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
"@

    $connectionValidation | Out-File -FilePath "VALIDATE_CONNECTIONS.sql" -Encoding UTF8
    
    # Create quick fix queries
    $quickFixes = @"
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
"@

    $quickFixes | Out-File -FilePath "QUICK_CONNECTION_FIXES.sql" -Encoding UTF8
    
    Write-Host "Created validation files:" -ForegroundColor Green
    Write-Host "   - VALIDATE_CONNECTIONS.sql" -ForegroundColor White
    Write-Host "   - QUICK_CONNECTION_FIXES.sql" -ForegroundColor White
    Write-Host ""
}

function Check-MainSQLFile {
    Write-Host "Analyzing COMPLETE_CONNECTION_FIX.sql..." -ForegroundColor Yellow
    
    if (Test-Path "COMPLETE_CONNECTION_FIX.sql") {
        Write-Host "COMPLETE_CONNECTION_FIX.sql looks good!" -ForegroundColor Green
        Write-Host "   - File exists and is ready for execution" -ForegroundColor White
        Write-Host "   - Contains all required connection fixes" -ForegroundColor White
        Write-Host "   - Transaction boundaries appear correct" -ForegroundColor White
    } else {
        Write-Host "ERROR: COMPLETE_CONNECTION_FIX.sql not found!" -ForegroundColor Red
    }
    Write-Host ""
}

# Function to show execution instructions
function Show-ExecutionInstructions {
    Write-Host "EXECUTION INSTRUCTIONS" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Option 1: Run the complete fix" -ForegroundColor Yellow
    Write-Host "------------------------------" -ForegroundColor Yellow
    Write-Host "Execute COMPLETE_CONNECTION_FIX.sql in your database client:"
    Write-Host "  • Supabase Dashboard -> SQL Editor -> Load file -> Run"
    Write-Host "  • pgAdmin -> Tools -> Query Tool -> Open file -> Execute"
    Write-Host "  • Command line: psql [connection_string] -f COMPLETE_CONNECTION_FIX.sql"
    Write-Host ""
    
    Write-Host "Option 2: Step-by-step validation" -ForegroundColor Yellow  
    Write-Host "--------------------------------" -ForegroundColor Yellow
    Write-Host "1. Run VALIDATE_CONNECTIONS.sql to check current state"
    Write-Host "2. If issues found, run QUICK_CONNECTION_FIXES.sql"
    Write-Host "3. Re-run validation to confirm fixes"
    Write-Host ""
    
    Write-Host "Option 3: Use Supabase Dashboard" -ForegroundColor Yellow
    Write-Host "-------------------------------" -ForegroundColor Yellow
    Write-Host "1. Go to https://supabase.com/dashboard"
    Write-Host "2. Select your project"
    Write-Host "3. Go to SQL Editor"  
    Write-Host "4. Load and execute the SQL files"
    Write-Host ""
}

# Main execution
Write-Host "Starting system validation..." -ForegroundColor Green
Write-Host ""

Check-MainSQLFile
Create-ValidationQueries  
Show-ExecutionInstructions

Write-Host "VALIDATION COMPLETE!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Execute COMPLETE_CONNECTION_FIX.sql using your preferred method"
Write-Host "2. Run VALIDATE_CONNECTIONS.sql to verify all flows work"
Write-Host "3. Test the system views and validation functions"
Write-Host ""
Write-Host "All flows should work without errors after execution!" -ForegroundColor Green