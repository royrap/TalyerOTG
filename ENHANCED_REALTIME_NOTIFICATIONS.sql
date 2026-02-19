-- =====================================================
-- REALTIME SUBSCRIPTION FIX PARA SA MECHANICS
-- Para makakuha ng notifications for both broadcast at shop-based requests
-- =====================================================

-- STEP 1: Create comprehensive realtime notification system
-- =====================================================

-- Function to send realtime notifications to mechanics
CREATE OR REPLACE FUNCTION send_mechanic_notification(
    p_mechanic_id uuid,
    p_request_id uuid,
    p_notification_type text DEFAULT 'new_service_request'
)
RETURNS boolean AS $$
DECLARE
    v_notification_payload jsonb;
    v_request_data RECORD;
    v_customer_data RECORD;
    v_shop_data RECORD;
BEGIN
    -- Get request data
    SELECT * INTO v_request_data FROM service_requests WHERE id = p_request_id;
    
    IF NOT FOUND THEN
        RAISE WARNING 'Request not found: %', p_request_id;
        RETURN false;
    END IF;
    
    -- Get customer data
    SELECT * INTO v_customer_data FROM user_profiles WHERE id = v_request_data.customer_id;
    
    -- Get shop data if applicable
    IF v_request_data.shop_id IS NOT NULL THEN
        SELECT * INTO v_shop_data FROM shops WHERE id = v_request_data.shop_id;
    END IF;
    
    -- Build comprehensive notification payload
    v_notification_payload := jsonb_build_object(
        'type', p_notification_type,
        'request_id', p_request_id,
        'mechanic_id', p_mechanic_id,
        'request_data', jsonb_build_object(
            'id', v_request_data.id,
            'title', v_request_data.title,
            'description', v_request_data.description,
            'status', v_request_data.status,
            'request_type', v_request_data.request_type,
            'pickup_address', v_request_data.pickup_address,
            'pickup_latitude', v_request_data.pickup_latitude,
            'pickup_longitude', v_request_data.pickup_longitude,
            'created_at', v_request_data.created_at,
            'shop_id', v_request_data.shop_id
        ),
        'customer_data', jsonb_build_object(
            'id', v_customer_data.id,
            'name', COALESCE(v_customer_data.first_name || ' ' || v_customer_data.last_name, v_customer_data.email),
            'email', v_customer_data.email,
            'phone', v_customer_data.phone_number
        ),
        'shop_data', CASE 
            WHEN v_shop_data.id IS NOT NULL THEN 
                jsonb_build_object(
                    'id', v_shop_data.id,
                    'name', v_shop_data.shop_name,
                    'address', v_shop_data.shop_address
                )
            ELSE NULL
        END,
        'routing_info', jsonb_build_object(
            'is_shop_based', v_request_data.shop_id IS NOT NULL,
            'is_broadcast', v_request_data.shop_id IS NULL,
            'routing_type', CASE 
                WHEN v_request_data.shop_id IS NOT NULL THEN 'shop_based'
                ELSE 'broadcast'
            END
        ),
        'timestamp', extract(epoch from NOW()),
        'notification_id', gen_random_uuid()
    );
    
    -- Send to mechanic-specific channel
    PERFORM pg_notify(
        'mechanic_channel_' || p_mechanic_id::text,
        v_notification_payload::text
    );
    
    -- Also send to general mechanics channel for backup
    PERFORM pg_notify(
        'mechanics_general',
        v_notification_payload::text
    );
    
    RAISE NOTICE 'Notification sent to mechanic % for request %', p_mechanic_id, p_request_id;
    RETURN true;
    
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to send notification to mechanic %: %', p_mechanic_id, SQLERRM;
    RETURN false;
END;
$$ LANGUAGE plpgsql;

-- STEP 2: Update broadcast function to use new notification system
-- =====================================================

CREATE OR REPLACE FUNCTION broadcast_service_request(
    request_id_param text,
    customer_lat numeric,
    customer_lng numeric,
    radius_km numeric DEFAULT 10.0
)
RETURNS jsonb AS $$
DECLARE
    eligible_mechanics_cursor CURSOR FOR
        SELECT 
            mas.mechanic_id,
            up.email,
            up.first_name,
            up.last_name,
            mas.location_latitude,
            mas.location_longitude,
            (6371 * acos(
                cos(radians(customer_lat)) * 
                cos(radians(mas.location_latitude)) * 
                cos(radians(mas.location_longitude) - radians(customer_lng)) + 
                sin(radians(customer_lat)) * 
                sin(radians(mas.location_latitude))
            )) AS distance_km
        FROM mechanic_availability_status mas
        JOIN user_profiles up ON up.id = mas.mechanic_id
        WHERE mas.current_status = 'available'
        AND mas.is_accepting_requests = true
        AND mas.location_latitude IS NOT NULL
        AND mas.location_longitude IS NOT NULL
        AND mas.current_request_id IS NULL
        AND (6371 * acos(
            cos(radians(customer_lat)) * 
            cos(radians(mas.location_latitude)) * 
            cos(radians(mas.location_longitude) - radians(customer_lng)) + 
            sin(radians(customer_lat)) * 
            sin(radians(mas.location_latitude))
        )) <= radius_km;
        
    mechanic_record RECORD;
    mechanics_notified INTEGER := 0;
    result_data jsonb;
    mechanic_emails text[] := '{}';
BEGIN
    RAISE NOTICE 'Starting broadcast for request % at lat: %, lng: %, radius: %km', 
                 request_id_param, customer_lat, customer_lng, radius_km;
    
    -- Clear any existing routing entries for this request
    DELETE FROM request_routing WHERE request_id = request_id_param::uuid;
    
    -- Find and notify eligible mechanics
    FOR mechanic_record IN eligible_mechanics_cursor LOOP
        BEGIN
            -- Insert routing record
            INSERT INTO request_routing (
                request_id,
                eligible_mechanic_id,
                distance_km,
                routing_type,
                is_notified,
                created_at
            ) VALUES (
                request_id_param::uuid,
                mechanic_record.mechanic_id,
                mechanic_record.distance_km,
                'broadcast',
                true,
                NOW()
            );
            
            -- Send realtime notification
            PERFORM send_mechanic_notification(
                mechanic_record.mechanic_id,
                request_id_param::uuid,
                'new_service_request'
            );
            
            mechanics_notified := mechanics_notified + 1;
            mechanic_emails := mechanic_emails || mechanic_record.email;
            
            RAISE NOTICE 'Notified mechanic: % (%.2f km away)', 
                         mechanic_record.email, mechanic_record.distance_km;
                         
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Failed to notify mechanic %: %', mechanic_record.email, SQLERRM;
        END;
    END LOOP;
    
    -- Update service request with notification count
    UPDATE service_requests 
    SET mechanics_notified_count = mechanics_notified,
        broadcast_timestamp = NOW(),
        request_type = 'broadcast'
    WHERE id = request_id_param::uuid;
    
    -- Build result
    result_data := jsonb_build_object(
        'success', true,
        'request_id', request_id_param,
        'mechanics_notified', mechanics_notified,
        'notified_mechanics', mechanic_emails,
        'broadcast_radius_km', radius_km,
        'broadcast_timestamp', NOW()
    );
    
    RAISE NOTICE 'Broadcast completed: % mechanics notified', mechanics_notified;
    RETURN result_data;
    
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Broadcast failed for request %: %', request_id_param, SQLERRM;
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM,
        'request_id', request_id_param
    );
END;
$$ LANGUAGE plpgsql;

-- STEP 3: Update shop-based routing function to use new notification system
-- =====================================================

CREATE OR REPLACE FUNCTION handle_shop_based_routing()
RETURNS TRIGGER AS $$
DECLARE
    v_shop_mechanics_count integer;
    v_mechanic_record RECORD;
BEGIN
    -- Only handle shop-based requests (shop_id is NOT NULL)
    IF NEW.shop_id IS NOT NULL THEN
        RAISE NOTICE 'Processing shop-based request: % for shop: %', NEW.id, NEW.shop_id;
        
        -- Count available mechanics in the shop
        SELECT COUNT(*) INTO v_shop_mechanics_count
        FROM shop_mechanics sm
        JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
        WHERE sm.shop_id = NEW.shop_id
        AND sm.is_active = true
        AND sm.is_available = true
        AND mas.current_status = 'available'
        AND mas.is_accepting_requests = true;
        
        RAISE NOTICE 'Found % available mechanics in shop', v_shop_mechanics_count;
        
        -- Update request with shop mechanic count
        UPDATE service_requests 
        SET mechanics_notified_count = v_shop_mechanics_count,
            request_type = 'shop_based'
        WHERE id = NEW.id;
        
        -- Clear any existing routing entries
        DELETE FROM request_routing WHERE request_id = NEW.id;
        
        -- Notify all shop mechanics
        FOR v_mechanic_record IN
            SELECT 
                sm.mechanic_id,
                up.email,
                up.first_name,
                up.last_name,
                mas.current_status,
                mas.is_accepting_requests
            FROM shop_mechanics sm
            JOIN user_profiles up ON up.id = sm.mechanic_id
            JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
            WHERE sm.shop_id = NEW.shop_id
            AND sm.is_active = true
            AND sm.is_available = true
            AND mas.current_status = 'available'
            AND mas.is_accepting_requests = true
        LOOP
            BEGIN
                RAISE NOTICE 'Notifying shop mechanic: % (%)', v_mechanic_record.email, v_mechanic_record.mechanic_id;
                
                -- Create routing record
                INSERT INTO request_routing (
                    request_id,
                    eligible_mechanic_id,
                    routing_type,
                    distance_km,
                    is_notified,
                    created_at,
                    shop_id
                ) VALUES (
                    NEW.id,
                    v_mechanic_record.mechanic_id,
                    'shop_based',
                    0.0, -- Shop-based requests don't need distance calculation
                    true,
                    NOW(),
                    NEW.shop_id
                );
                
                -- Send realtime notification using new system
                PERFORM send_mechanic_notification(
                    v_mechanic_record.mechanic_id,
                    NEW.id,
                    'new_service_request'
                );
                
                RAISE NOTICE 'Successfully notified shop mechanic: %', v_mechanic_record.email;
                
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'Failed to notify shop mechanic %: %', v_mechanic_record.email, SQLERRM;
            END;
        END LOOP;
        
        RAISE NOTICE 'Shop-based routing completed for request: %', NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- STEP 4: Create mechanic subscription guide
-- =====================================================

-- This creates the channels that mechanics should subscribe to in their mobile apps
SELECT 
    'MECHANIC SUBSCRIPTION CHANNELS' as info_type,
    up.email as mechanic_email,
    up.id as mechanic_id,
    'mechanic_channel_' || up.id::text as primary_channel,
    'mechanics_general' as backup_channel,
    jsonb_build_object(
        'subscribe_to', array['mechanic_channel_' || up.id::text, 'mechanics_general'],
        'notification_types', array['new_service_request', 'request_accepted', 'request_cancelled'],
        'payload_structure', jsonb_build_object(
            'type', 'notification type',
            'request_id', 'UUID of the request',
            'mechanic_id', 'UUID of the mechanic',
            'request_data', 'Full request details',
            'customer_data', 'Customer information',
            'shop_data', 'Shop details (if shop-based)',
            'routing_info', 'How the request was routed',
            'timestamp', 'Unix timestamp',
            'notification_id', 'Unique notification ID'
        )
    ) as subscription_info
FROM user_profiles up
WHERE up.email IN ('yujirofuma28@gmail.com', 'rafaelpineda471@gmail.com');

-- STEP 5: Test both routing scenarios with new notification system
-- =====================================================

DO $$
DECLARE
    v_customer_id uuid;
    v_test_shop_id uuid;
    v_broadcast_request_id uuid := gen_random_uuid();
    v_shop_request_id uuid := gen_random_uuid();
    v_yujiro_id uuid;
    v_rafael_id uuid;
    v_broadcast_result jsonb;
BEGIN
    -- Get mechanic IDs
    SELECT id INTO v_yujiro_id FROM user_profiles WHERE email = 'yujirofuma28@gmail.com';
    SELECT id INTO v_rafael_id FROM user_profiles WHERE email = 'rafaelpineda471@gmail.com';
    
    -- Get customer
    SELECT id INTO v_customer_id FROM user_profiles WHERE user_type = 'customer' LIMIT 1;
    
    -- Get test shop
    SELECT id INTO v_test_shop_id FROM shops WHERE shop_name LIKE '%Test%' LIMIT 1;
    
    IF v_test_shop_id IS NULL THEN
        INSERT INTO shops (id, owner_id, shop_name, shop_address, latitude, longitude, is_active)
        VALUES (gen_random_uuid(), v_yujiro_id, 'Test Notification Shop', 'Manila Test Location', 14.5995, 120.9842, true)
        RETURNING id INTO v_test_shop_id;
    END IF;
    
    -- Ensure both mechanics are in shop
    INSERT INTO shop_mechanics (shop_id, mechanic_id, is_active, is_available)
    VALUES 
        (v_test_shop_id, v_yujiro_id, true, true),
        (v_test_shop_id, v_rafael_id, true, true)
    ON CONFLICT (shop_id, mechanic_id) DO UPDATE SET
        is_active = true,
        is_available = true;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== TESTING ENHANCED NOTIFICATION SYSTEM ===';
    
    -- Test 1: Broadcast request (no shop selected)
    INSERT INTO service_requests (
        id, customer_id, title, description, pickup_latitude, pickup_longitude,
        pickup_address, shop_id, status, request_type
    ) VALUES (
        v_broadcast_request_id, v_customer_id,
        'BROADCAST TEST: Both Mechanics Should See This (No Shop)',
        'Emergency towing needed - broadcast to all nearby mechanics',
        14.5995, 120.9842, 'Manila Test Location',
        NULL, 'pending', 'broadcast'
    );
    
    RAISE NOTICE 'Created broadcast test request: %', v_broadcast_request_id;
    
    -- Test 2: Shop-based request (shop selected)
    INSERT INTO service_requests (
        id, customer_id, title, description, pickup_latitude, pickup_longitude,
        pickup_address, shop_id, status, request_type
    ) VALUES (
        v_shop_request_id, v_customer_id,
        'SHOP TEST: Both Mechanics Should See This (Shop Selected)',
        'Oil change service - sent to specific shop mechanics',
        14.5995, 120.9842, 'Manila Test Location',
        v_test_shop_id, 'pending', 'shop_based'
    );
    
    RAISE NOTICE 'Created shop-based test request: %', v_shop_request_id;
    RAISE NOTICE 'Shop ID: %', v_test_shop_id;
    
END $$;

-- STEP 6: Verify all notifications were sent
-- =====================================================

-- Check broadcast routing
SELECT 
    'BROADCAST ROUTING CHECK' as test_type,
    sr.title,
    sr.mechanics_notified_count,
    COUNT(rr.eligible_mechanic_id) as actual_routes,
    array_agg(up.email ORDER BY up.email) as notified_mechanics
FROM service_requests sr
LEFT JOIN request_routing rr ON rr.request_id = sr.id
LEFT JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
WHERE sr.title LIKE 'BROADCAST TEST:%'
GROUP BY sr.id, sr.title, sr.mechanics_notified_count;

-- Check shop routing
SELECT 
    'SHOP ROUTING CHECK' as test_type,
    sr.title,
    sr.mechanics_notified_count,
    COUNT(rr.eligible_mechanic_id) as actual_routes,
    array_agg(up.email ORDER BY up.email) as notified_mechanics
FROM service_requests sr
LEFT JOIN request_routing rr ON rr.request_id = sr.id
LEFT JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
WHERE sr.title LIKE 'SHOP TEST:%'
GROUP BY sr.id, sr.title, sr.mechanics_notified_count;

RAISE NOTICE '';
RAISE NOTICE '=== ENHANCED NOTIFICATION SYSTEM SETUP COMPLETE ===';
RAISE NOTICE '1. Both mechanics should now receive ALL types of requests';
RAISE NOTICE '2. Broadcast requests: Both mechanics within 10km radius';
RAISE NOTICE '3. Shop requests: Both mechanics assigned to the shop';
RAISE NOTICE '4. Enhanced realtime notifications with full payload data';
RAISE NOTICE '5. Multiple notification channels for reliability';
RAISE NOTICE '';
RAISE NOTICE 'MOBILE APP INTEGRATION:';
RAISE NOTICE '- Subscribe to mechanic_channel_[mechanic_id] for each mechanic';
RAISE NOTICE '- Also subscribe to mechanics_general as backup';
RAISE NOTICE '- Parse JSON payload for complete request information';
RAISE NOTICE '- Check routing_info.routing_type for request source';