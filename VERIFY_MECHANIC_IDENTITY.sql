-- ========================================
-- VERIFY WHO IS LOGGED IN AND WHO DID THE ₱220 JOB
-- ========================================

-- 1. CHECK ALL MECHANICS IN MECAID SUPPLY
SELECT 
    'All Mechanics in MechAid supply' as info,
    up.id as user_id,
    up.first_name || ' ' || up.last_name as mechanic_name,
    up.email,
    up.user_type,
    sm.shop_id,
    sm.is_active,
    sm.is_available
FROM shop_mechanics sm
INNER JOIN user_profiles up ON up.id = sm.mechanic_id
WHERE sm.shop_id = 'cedc2e63-7785-4d61-a8f1-9f4ed8d254da'
ORDER BY up.first_name;

-- 2. CHECK THE ₱220 FLAT TIRE JOB
SELECT 
    '₱220 Flat Tire Job Details' as info,
    mjh.id as job_history_id,
    mjh.job_title,
    mjh.total_amount,
    mjh.job_status,
    mjh.mechanic_id,
    mech.first_name || ' ' || mech.last_name as mechanic_name,
    mech.email as mechanic_email,
    cust.first_name || ' ' || cust.last_name as customer_name,
    cust.email as customer_email,
    mjh.shop_id,
    s.shop_name,
    mjh.completed_at
FROM mechanic_job_history mjh
LEFT JOIN user_profiles mech ON mech.id = mjh.mechanic_id
LEFT JOIN user_profiles cust ON cust.id = mjh.customer_id
LEFT JOIN shops s ON s.id = mjh.shop_id
WHERE mjh.total_amount = 220 AND mjh.job_title ILIKE '%flat%tire%'
ORDER BY mjh.created_at DESC
LIMIT 1;

-- 3. CHECK RAFAEL PINEDA USER ID
SELECT 
    'Rafael Pineda Details' as info,
    id as user_id,
    first_name || ' ' || last_name as full_name,
    email,
    user_type,
    phone_number
FROM user_profiles
WHERE LOWER(first_name || ' ' || last_name) LIKE '%rafael%pineda%'
   OR LOWER(email) LIKE '%rafael%'
   OR LOWER(first_name) LIKE '%rafael%';

-- 4. CHECK YUJIRO FUMA USER ID
SELECT 
    'Yujiro Fuma Details' as info,
    id as user_id,
    first_name || ' ' || last_name as full_name,
    email,
    user_type,
    phone_number
FROM user_profiles
WHERE LOWER(first_name || ' ' || last_name) LIKE '%yujiro%fuma%'
   OR LOWER(email) LIKE '%yujiro%'
   OR LOWER(first_name) LIKE '%yujiro%';

-- 5. TEST THE RPC FUNCTION FOR BOTH MECHANICS
-- (This will show what each mechanic sees in their history)

SELECT 
    '=====================================' as separator,
    'To test what RAFAEL sees, run this query WHILE LOGGED IN AS RAFAEL:' as instruction;
    
SELECT 
    job_title,
    mechanic_id,
    customer_first_name || ' ' || customer_last_name as customer,
    total_amount,
    job_status
FROM get_mechanic_job_history();
