        -- ====================================================================
        -- DEBUG REQUEST: bbb8b1e8-d2f8-4f0f-8e28-4371a526d540
        -- ====================================================================

        -- 1. Check request details
        SELECT 
            '=== REQUEST DETAILS ===' as section,
            id,
            title,
            preferred_shop_id,
            shop_id,
            request_type,
            broadcast_status,
            notified_providers_count,
            status,
            created_at
        FROM service_requests
        WHERE id = 'bbb8b1e8-d2f8-4f0f-8e28-4371a526d540'::uuid;

        -- 2. Check if shop_id is NULL or has value
        SELECT 
            '=== SHOP ID CHECK ===' as section,
            CASE 
                WHEN preferred_shop_id IS NULL THEN '❌ NULL - This is the problem! Should have shop ID!'
                ELSE '✅ Has shop ID: ' || preferred_shop_id::text
            END as diagnosis,
            CASE 
                WHEN shop_id IS NULL THEN 'shop_id: NULL'
                ELSE 'shop_id: ' || shop_id::text
            END as shop_id_status,
            request_type,
            broadcast_status
        FROM service_requests
        WHERE id = 'bbb8b1e8-d2f8-4f0f-8e28-4371a526d540'::uuid;

        -- 3. Check which mechanic received the notification
        SELECT 
            '=== WHO WAS NOTIFIED ===' as section,
            up.first_name || ' ' || up.last_name as mechanic_name,
            up.id as mechanic_id,
            s.shop_name as mechanic_shop,
            sm.shop_id as shop_id,
            rb.notification_sent_at
        FROM request_broadcasts rb
        LEFT JOIN user_profiles up ON up.id = rb.mechanic_id
        LEFT JOIN shop_mechanics sm ON sm.mechanic_id = rb.mechanic_id AND sm.is_active = true
        LEFT JOIN shops s ON s.id = sm.shop_id
        WHERE rb.request_id = 'bbb8b1e8-d2f8-4f0f-8e28-4371a526d540'::uuid;

        -- 4. Check the trigger execution
        SELECT 
            '=== TRIGGER ANALYSIS ===' as section,
            CASE 
                WHEN preferred_shop_id IS NULL THEN 
                    '🚨 PROBLEM: preferred_shop_id is NULL
                    → System treated this as BROADCAST request
                    → Sent to ALL mechanics instead of shop-specific
                    → FIX: Flutter app not passing shopId to database'
                WHEN broadcast_status = 'broadcasting' THEN
                    '🚨 PROBLEM: broadcast_status is "broadcasting" 
                    → Trigger function sent notifications
                    → Should be "no_mechanics_available"
                    → FIX: Trigger not using new function or shop has mechanics'
                WHEN broadcast_status = 'no_mechanics_available' THEN
                    '✅ CORRECT: Trigger detected no mechanics
                    → But notification still sent? Check request_broadcasts table'
                ELSE
                    '⚠️ UNKNOWN STATUS: ' || COALESCE(broadcast_status, 'NULL')
            END as diagnosis
        FROM service_requests
        WHERE id = 'bbb8b1e8-d2f8-4f0f-8e28-4371a526d540'::uuid;

        -- 5. Verify which shop was selected (if any)
        SELECT 
            '=== EXPECTED SHOP ===' as section,
            s.shop_name,
            s.id as shop_id,
            COUNT(sm.mechanic_id) as mechanics_count
        FROM service_requests sr
        LEFT JOIN shops s ON s.id = sr.preferred_shop_id
        LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id AND sm.is_active = true
        WHERE sr.id = 'bbb8b1e8-d2f8-4f0f-8e28-4371a526d540'::uuid
        GROUP BY s.id, s.shop_name;

        -- ====================================================================
        -- DIAGNOSIS SUMMARY
        -- ====================================================================
        /*
        POSSIBLE ISSUES:

        1. ❌ preferred_shop_id is NULL
        → Flutter app not passing shopId parameter
        → Check vehicle_details_screen.dart debug logs
        → Check enhanced_service_request_service.dart logs
        → Verify preSelectedMechanic data flow

        2. ❌ broadcast_status is 'broadcasting'
        → Trigger used old function (broadcast_service_request)
        → Should use new function (broadcast_service_request_with_shop_filter)
        → Re-run FIX_SHOP_SPECIFIC_ROUTING.sql

        3. ❌ Mechanic from different shop was notified
        → Broadcast mode activated (because preferred_shop_id is NULL)
        → System searched ALL mechanics instead of shop-specific

        NEXT STEPS:
        - Run this query to see exact issue
        - Check Flutter console logs for debug messages
        - Verify shopId is being passed from shop selection screen
        */
