-- ====================================================================
-- DIAGNOSE WHY MECHANICS DON'T SEE POPUP REQUESTS
-- ====================================================================
-- Run these queries to check broadcast request system

-- 1. Check recent service requests status
SELECT 
    id,
    title,
    status,
    request_type,
    is_broadcast_request,
    broadcast_status,
    created_at,
    customer_id
FROM service_requests
WHERE created_at > NOW() - INTERVAL '1 day'
ORDER BY created_at DESC
LIMIT 10;

-- 2. Check request_routing table for mechanic notifications
SELECT 
    rr.id,
    rr.request_id,
    rr.eligible_mechanic_id,
    rr.routing_type,
    rr.is_notified,
    rr.notified_at,
    rr.response_deadline,
    rr.distance_km,
    rr.created_at,
    sr.status as request_status,
    sr.title as request_title
FROM request_routing rr
LEFT JOIN service_requests sr ON sr.id = rr.request_id
WHERE rr.created_at > NOW() - INTERVAL '1 day'
ORDER BY rr.created_at DESC
LIMIT 20;

-- 3. Check request_broadcasts table
SELECT 
    rb.id,
    rb.request_id,
    rb.provider_id,
    rb.provider_type,
    rb.mechanic_id,
    rb.shop_id,
    rb.distance_km,
    rb.notification_sent_at,
    rb.viewed_at,
    rb.response_status,
    rb.responded_at,
    rb.is_eligible,
    sr.status as request_status,
    sr.title as request_title
FROM request_broadcasts rb
LEFT JOIN service_requests sr ON sr.id = rb.request_id
WHERE rb.created_at > NOW() - INTERVAL '1 day'
ORDER BY rb.created_at DESC
LIMIT 20;

-- 4. Check available mechanics count
SELECT 
    up.id,
    up.first_name || ' ' || up.last_name as mechanic_name,
    up.is_available,
    up.status,
    mas.current_status,
    mas.is_accepting_requests,
    mas.last_status_update,
    mas.location_latitude,
    mas.location_longitude
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic'
ORDER BY up.created_at DESC;

-- 5. Check if request_routing is being populated
SELECT COUNT(*) as total_routing_entries
FROM request_routing
WHERE created_at > NOW() - INTERVAL '1 day';

-- 6. Check if request_broadcasts is being populated
SELECT COUNT(*) as total_broadcast_entries
FROM request_broadcasts
WHERE created_at > NOW() - INTERVAL '1 day';

-- 7. Check recent customer requests and their routing
SELECT 
    sr.id as request_id,
    sr.title,
    sr.status,
    sr.request_type,
    sr.is_broadcast_request,
    sr.created_at,
    up.first_name || ' ' || up.last_name as customer_name,
    COUNT(rr.id) as routing_count,
    COUNT(rb.id) as broadcast_count
FROM service_requests sr
LEFT JOIN user_profiles up ON up.id = sr.customer_id
LEFT JOIN request_routing rr ON rr.request_id = sr.id
LEFT JOIN request_broadcasts rb ON rb.request_id = sr.id
WHERE sr.created_at > NOW() - INTERVAL '1 day'
GROUP BY sr.id, sr.title, sr.status, sr.request_type, sr.is_broadcast_request, sr.created_at, up.first_name, up.last_name
ORDER BY sr.created_at DESC;

-- 8. Check if there are any active mechanics online
SELECT 
    COUNT(*) as online_mechanics_count
FROM mechanic_availability_status
WHERE current_status = 'available'
    AND is_accepting_requests = true
    AND last_active_at > NOW() - INTERVAL '5 minutes';

-- 9. Check service provider records for mechanics
SELECT 
    sp.id,
    sp.user_id,
    sp.is_available,
    sp.status,
    up.first_name || ' ' || up.last_name as mechanic_name,
    up.user_type
FROM service_providers sp
JOIN user_profiles up ON up.id = sp.user_id
WHERE up.user_type = 'mechanic'
ORDER BY sp.created_at DESC;

-- 10. Check if broadcast function exists
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_name LIKE '%broadcast%'
    AND routine_schema = 'public';
