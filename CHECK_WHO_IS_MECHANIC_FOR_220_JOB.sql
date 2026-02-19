-- ========================================
-- CHECK WHO IS THE MECHANIC FOR ₱220 JOB
-- ========================================

SELECT 
    mjh.id as job_history_id,
    mjh.job_title,
    mjh.total_amount,
    mjh.job_status,
    mjh.completed_at,
    mjh.mechanic_id,
    up.first_name || ' ' || up.last_name as mechanic_name,
    up.email as mechanic_email,
    cust.first_name || ' ' || cust.last_name as customer_name
FROM mechanic_job_history mjh
LEFT JOIN user_profiles up ON up.id = mjh.mechanic_id
LEFT JOIN user_profiles cust ON cust.id = mjh.customer_id
WHERE mjh.total_amount = 220
ORDER BY mjh.created_at DESC;

-- ========================================
-- CHECK ALL MECHANICS IN MECAID SUPPLY
-- ========================================

SELECT 
    sm.mechanic_id,
    up.first_name || ' ' || up.last_name as mechanic_name,
    up.email as mechanic_email,
    sm.is_active,
    sm.is_available
FROM shop_mechanics sm
LEFT JOIN user_profiles up ON up.id = sm.mechanic_id
WHERE sm.shop_id = 'cedc2e63-7785-4d61-a8f1-9f4ed8d254da'
ORDER BY up.first_name;

-- ========================================
-- CHECK RAFAEL PINEDA's USER ID
-- ========================================

SELECT 
    id as user_id,
    first_name,
    last_name,
    email,
    user_type
FROM user_profiles
WHERE LOWER(first_name) LIKE '%rafael%' 
   OR LOWER(last_name) LIKE '%pineda%'
   OR LOWER(email) LIKE '%rafael%'
   OR LOWER(email) LIKE '%pineda%';
