-- ====================================================================
-- BROADCAST REQUEST SYSTEM IMPLEMENTATION
-- ====================================================================
-- This implements the system where customers can make requests without 
-- selecting specific shops, and all nearby available mechanics/shops 
-- can see and compete for the request on a first-come-first-served basis.

-- ====================================================================
-- 1. UPDATE SERVICE_REQUESTS TABLE FOR BROADCAST FUNCTIONALITY
-- ====================================================================

-- Add new columns to support broadcast requests
ALTER TABLE public.service_requests 
ADD COLUMN IF NOT EXISTS is_broadcast_request boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS broadcast_radius_km numeric DEFAULT 10.0,
ADD COLUMN IF NOT EXISTS broadcast_started_at timestamp with time zone,
ADD COLUMN IF NOT EXISTS broadcast_expires_at timestamp with time zone,
ADD COLUMN IF NOT EXISTS max_response_time_minutes integer DEFAULT 30,
ADD COLUMN IF NOT EXISTS notified_providers_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS first_response_at timestamp with time zone,
ADD COLUMN IF NOT EXISTS broadcast_status text DEFAULT 'not_started' CHECK (broadcast_status = ANY (ARRAY['not_started'::text, 'broadcasting'::text, 'accepted'::text, 'expired'::text, 'cancelled'::text]));

-- Update the request_type enum to include broadcast type
ALTER TABLE public.service_requests 
DROP CONSTRAINT IF EXISTS service_requests_request_type_check;

ALTER TABLE public.service_requests 
ADD CONSTRAINT service_requests_request_type_check 
CHECK (request_type = ANY (ARRAY['direct_mechanic'::text, 'shop_based'::text, 'broadcast'::text]));

-- ====================================================================
-- 2. CREATE REQUEST_BROADCASTS TABLE
-- ====================================================================
-- This table tracks which providers have been notified about broadcast requests

DROP TABLE IF EXISTS public.request_broadcasts CASCADE;

CREATE TABLE public.request_broadcasts (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    request_id uuid NOT NULL,
    provider_id uuid NOT NULL, -- can be shop or individual mechanic
    provider_type text NOT NULL CHECK (provider_type = ANY (ARRAY['shop'::text, 'mechanic'::text])),
    shop_id uuid, -- if provider is a shop
    mechanic_id uuid, -- if provider is individual mechanic
    distance_km numeric NOT NULL,
    notification_sent_at timestamp with time zone DEFAULT now(),
    notification_method text DEFAULT 'push' CHECK (notification_method = ANY (ARRAY['push'::text, 'sms'::text, 'email'::text])),
    viewed_at timestamp with time zone,
    response_status text DEFAULT 'pending' CHECK (response_status = ANY (ARRAY['pending'::text, 'viewed'::text, 'accepted'::text, 'declined'::text, 'expired'::text])),
    responded_at timestamp with time zone,
    response_time_seconds integer,
    decline_reason text,
    is_eligible boolean DEFAULT true,
    eligibility_reasons jsonb DEFAULT '[]'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    
    CONSTRAINT request_broadcasts_pkey PRIMARY KEY (id),
    CONSTRAINT request_broadcasts_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.service_requests(id) ON DELETE CASCADE,
    CONSTRAINT request_broadcasts_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.service_providers(id),
    CONSTRAINT request_broadcasts_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES public.shops(id),
    CONSTRAINT request_broadcasts_mechanic_id_fkey FOREIGN KEY (mechanic_id) REFERENCES public.user_profiles(id),
    
    -- Ensure unique notification per request per provider
    CONSTRAINT request_broadcasts_unique_notification UNIQUE (request_id, provider_id)
);

-- Index for faster queries
CREATE INDEX idx_request_broadcasts_request_id ON public.request_broadcasts(request_id);
CREATE INDEX idx_request_broadcasts_provider_id ON public.request_broadcasts(provider_id);
CREATE INDEX idx_request_broadcasts_response_status ON public.request_broadcasts(response_status);
CREATE INDEX idx_request_broadcasts_notification_sent ON public.request_broadcasts(notification_sent_at);

-- ====================================================================
-- 3. CREATE PROVIDER_AVAILABILITY_CACHE TABLE
-- ====================================================================
-- Cache table for faster availability checking

DROP TABLE IF EXISTS public.provider_availability_cache CASCADE;

CREATE TABLE public.provider_availability_cache (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    provider_id uuid NOT NULL UNIQUE,
    provider_type text NOT NULL CHECK (provider_type = ANY (ARRAY['shop'::text, 'mechanic'::text])),
    is_available boolean DEFAULT true,
    is_accepting_requests boolean DEFAULT true,
    current_location_lat numeric,
    current_location_lng numeric,
    service_radius_km numeric DEFAULT 10.0,
    max_concurrent_jobs integer DEFAULT 5,
    current_active_jobs integer DEFAULT 0,
    availability_status text DEFAULT 'available' CHECK (availability_status = ANY (ARRAY['available'::text, 'busy'::text, 'offline'::text, 'maintenance'::text])),
    last_activity_at timestamp with time zone DEFAULT now(),
    last_updated_at timestamp with time zone DEFAULT now(),
    operating_hours jsonb DEFAULT '{"monday": {"open": "08:00", "close": "18:00"}, "tuesday": {"open": "08:00", "close": "18:00"}, "wednesday": {"open": "08:00", "close": "18:00"}, "thursday": {"open": "08:00", "close": "18:00"}, "friday": {"open": "08:00", "close": "18:00"}, "saturday": {"open": "08:00", "close": "16:00"}, "sunday": {"open": null, "close": null}}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    
    CONSTRAINT provider_availability_cache_pkey PRIMARY KEY (id),
    CONSTRAINT provider_availability_cache_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.service_providers(id) ON DELETE CASCADE
);

-- Index for location-based queries
CREATE INDEX idx_provider_availability_location ON public.provider_availability_cache USING btree(current_location_lat, current_location_lng);
CREATE INDEX idx_provider_availability_status ON public.provider_availability_cache(availability_status);

-- ====================================================================
-- 4. CREATE FUNCTION TO FIND ELIGIBLE PROVIDERS
-- ====================================================================

CREATE OR REPLACE FUNCTION find_eligible_providers_for_broadcast(
    p_request_id uuid,
    p_customer_lat numeric,
    p_customer_lng numeric,
    p_service_category_id uuid,
    p_max_radius_km numeric DEFAULT 25.0
)
RETURNS TABLE(
    provider_id uuid,
    provider_type text,
    shop_id uuid,
    mechanic_id uuid,
    distance_km numeric,
    is_available boolean,
    estimated_arrival_minutes integer
) AS $$
BEGIN
    RETURN QUERY
    WITH available_shops AS (
        -- Find shops that are open and have available mechanics
        SELECT 
            sp.id as provider_id,
            'shop'::text as provider_type,
            s.id as shop_id,
            NULL::uuid as mechanic_id,
            -- Calculate distance using Haversine formula (approximate)
            (6371 * acos(
                cos(radians(p_customer_lat)) * 
                cos(radians(s.latitude)) * 
                cos(radians(s.longitude) - radians(p_customer_lng)) + 
                sin(radians(p_customer_lat)) * 
                sin(radians(s.latitude))
            )) as distance_km,
            true as is_available,
            -- Estimate arrival time based on distance (assuming 30 km/h average speed)
            GREATEST(15, ROUND((6371 * acos(
                cos(radians(p_customer_lat)) * 
                cos(radians(s.latitude)) * 
                cos(radians(s.longitude) - radians(p_customer_lng)) + 
                sin(radians(p_customer_lat)) * 
                sin(radians(s.latitude))
            )) * 2))::integer as estimated_arrival_minutes
        FROM public.service_providers sp
        JOIN public.shops s ON s.owner_id = sp.user_id
        LEFT JOIN public.shop_services ss ON ss.shop_id = s.id
        WHERE 
            sp.is_available = true
            AND sp.is_verified = true
            AND s.is_active = true
            AND s.current_status = 'open'
            AND s.latitude IS NOT NULL 
            AND s.longitude IS NOT NULL
            AND (ss.category_id = p_service_category_id OR ss.category_id IS NULL)
            -- Check if shop has available mechanics
            AND EXISTS (
                SELECT 1 FROM public.shop_mechanics sm
                JOIN public.mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
                WHERE sm.shop_id = s.id 
                AND sm.is_active = true 
                AND mas.current_status = 'available'
                AND mas.is_accepting_requests = true
            )
        
        UNION ALL
        
        -- Find independent mechanics (not bound to shops)
        SELECT 
            sp.id as provider_id,
            'mechanic'::text as provider_type,
            NULL::uuid as shop_id,
            sp.user_id as mechanic_id,
            -- Calculate distance
            (6371 * acos(
                cos(radians(p_customer_lat)) * 
                cos(radians(sp.current_latitude)) * 
                cos(radians(sp.current_longitude) - radians(p_customer_lng)) + 
                sin(radians(p_customer_lat)) * 
                sin(radians(sp.current_latitude))
            )) as distance_km,
            true as is_available,
            -- Estimate arrival time
            GREATEST(10, ROUND((6371 * acos(
                cos(radians(p_customer_lat)) * 
                cos(radians(sp.current_latitude)) * 
                cos(radians(sp.current_longitude) - radians(p_customer_lng)) + 
                sin(radians(p_customer_lat)) * 
                sin(radians(sp.current_latitude))
            )) * 2))::integer as estimated_arrival_minutes
        FROM public.service_providers sp
        LEFT JOIN public.mechanic_availability_status mas ON mas.mechanic_id = sp.user_id
        WHERE 
            sp.is_available = true
            AND sp.is_verified = true
            AND sp.current_latitude IS NOT NULL 
            AND sp.current_longitude IS NOT NULL
            AND sp.shop_id IS NULL -- Independent mechanics only
            AND (mas.current_status = 'available' OR mas.current_status IS NULL)
            AND (mas.is_accepting_requests = true OR mas.is_accepting_requests IS NULL)
            -- Check if mechanic provides the requested service
            AND EXISTS (
                SELECT 1 FROM public.provider_services ps
                WHERE ps.provider_id = sp.id 
                AND ps.category_id = p_service_category_id
                AND ps.is_available = true
            )
    )
    SELECT * FROM available_shops 
    WHERE distance_km <= p_max_radius_km
    ORDER BY distance_km ASC, estimated_arrival_minutes ASC;
END;
$$ LANGUAGE plpgsql;

-- ====================================================================
-- 5. CREATE FUNCTION TO BROADCAST REQUEST
-- ====================================================================

CREATE OR REPLACE FUNCTION broadcast_service_request(
    p_request_id uuid,
    p_max_radius_km numeric DEFAULT 25.0,
    p_response_timeout_minutes integer DEFAULT 30
)
RETURNS jsonb AS $$
DECLARE
    v_request_data record;
    v_provider record;
    v_notified_count integer := 0;
    v_result jsonb;
BEGIN
    -- Get request details
    SELECT customer_id, pickup_latitude, pickup_longitude, category_id, title, description
    INTO v_request_data
    FROM public.service_requests 
    WHERE id = p_request_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Request not found');
    END IF;
    
    -- Update request to broadcast mode
    UPDATE public.service_requests 
    SET 
        is_broadcast_request = true,
        broadcast_radius_km = p_max_radius_km,
        broadcast_started_at = now(),
        broadcast_expires_at = now() + (p_response_timeout_minutes || ' minutes')::interval,
        max_response_time_minutes = p_response_timeout_minutes,
        broadcast_status = 'broadcasting',
        request_type = 'broadcast'
    WHERE id = p_request_id;
    
    -- Find and notify eligible providers
    FOR v_provider IN 
        SELECT * FROM find_eligible_providers_for_broadcast(
            p_request_id, 
            v_request_data.pickup_latitude, 
            v_request_data.pickup_longitude, 
            v_request_data.category_id, 
            p_max_radius_km
        )
    LOOP
        -- Insert broadcast notification record
        INSERT INTO public.request_broadcasts (
            request_id,
            provider_id,
            provider_type,
            shop_id,
            mechanic_id,
            distance_km,
            notification_sent_at,
            is_eligible
        ) VALUES (
            p_request_id,
            v_provider.provider_id,
            v_provider.provider_type,
            v_provider.shop_id,
            v_provider.mechanic_id,
            v_provider.distance_km,
            now(),
            true
        );
        
        -- Also insert to request_routing for compatibility
        INSERT INTO public.request_routing (
            request_id,
            eligible_mechanic_id,
            eligible_shop_id,
            routing_type,
            is_notified,
            notified_at,
            response_deadline
        ) VALUES (
            p_request_id,
            v_provider.mechanic_id,
            v_provider.shop_id,
            'any_available',
            true,
            now(),
            now() + (p_response_timeout_minutes || ' minutes')::interval
        );
        
        v_notified_count := v_notified_count + 1;
    END LOOP;
    
    -- Update notified count
    UPDATE public.service_requests 
    SET notified_providers_count = v_notified_count
    WHERE id = p_request_id;
    
    v_result := jsonb_build_object(
        'success', true,
        'request_id', p_request_id,
        'notified_providers', v_notified_count,
        'broadcast_radius_km', p_max_radius_km,
        'expires_at', (now() + (p_response_timeout_minutes || ' minutes')::interval)
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ====================================================================
-- 6. CREATE FUNCTION TO ACCEPT BROADCAST REQUEST
-- ====================================================================

CREATE OR REPLACE FUNCTION accept_broadcast_request(
    p_request_id uuid,
    p_provider_id uuid,
    p_mechanic_id uuid DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
    v_current_status text;
    v_provider_type text;
    v_shop_id uuid;
    v_result jsonb;
BEGIN
    -- Check if request is still available for acceptance
    SELECT broadcast_status INTO v_current_status
    FROM public.service_requests 
    WHERE id = p_request_id;
    
    IF v_current_status != 'broadcasting' THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'Request is no longer available',
            'current_status', v_current_status
        );
    END IF;
    
    -- Get provider details
    SELECT 
        CASE WHEN sp.shop_id IS NOT NULL THEN 'shop' ELSE 'mechanic' END,
        sp.shop_id
    INTO v_provider_type, v_shop_id
    FROM public.service_providers sp
    WHERE sp.id = p_provider_id;
    
    -- Begin transaction to ensure atomicity
    BEGIN
        -- Update the service request
        UPDATE public.service_requests 
        SET 
            provider_id = p_provider_id,
            assigned_mechanic_id = COALESCE(p_mechanic_id, (
                SELECT user_id FROM public.service_providers WHERE id = p_provider_id
            )),
            shop_id = v_shop_id,
            status = 'accepted',
            broadcast_status = 'accepted',
            accepted_at = now(),
            accepted_by = COALESCE(p_mechanic_id, (
                SELECT user_id FROM public.service_providers WHERE id = p_provider_id
            )),
            first_response_at = now()
        WHERE id = p_request_id 
        AND broadcast_status = 'broadcasting'; -- Double-check it's still available
        
        -- Check if update was successful (no race condition)
        IF NOT FOUND THEN
            RETURN jsonb_build_object(
                'success', false, 
                'error', 'Request was already accepted by another provider'
            );
        END IF;
        
        -- Update the broadcast record for this provider
        UPDATE public.request_broadcasts 
        SET 
            response_status = 'accepted',
            responded_at = now(),
            response_time_seconds = EXTRACT(EPOCH FROM (now() - notification_sent_at))::integer
        WHERE request_id = p_request_id AND provider_id = p_provider_id;
        
        -- Mark all other broadcast notifications as expired
        UPDATE public.request_broadcasts 
        SET 
            response_status = 'expired',
            responded_at = now()
        WHERE request_id = p_request_id 
        AND provider_id != p_provider_id 
        AND response_status = 'pending';
        
        -- Update mechanic availability if applicable
        IF p_mechanic_id IS NOT NULL THEN
            UPDATE public.mechanic_availability_status
            SET 
                current_status = 'in_service',
                current_request_id = p_request_id,
                last_status_update = now()
            WHERE mechanic_id = p_mechanic_id;
        END IF;
        
        v_result := jsonb_build_object(
            'success', true,
            'request_id', p_request_id,
            'provider_id', p_provider_id,
            'provider_type', v_provider_type,
            'accepted_at', now()
        );
        
        RETURN v_result;
        
    EXCEPTION WHEN OTHERS THEN
        -- Rollback happens automatically
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'Failed to accept request: ' || SQLERRM
        );
    END;
END;
$$ LANGUAGE plpgsql;

-- ====================================================================
-- 7. CREATE FUNCTION TO GET AVAILABLE REQUESTS FOR PROVIDER
-- ====================================================================

CREATE OR REPLACE FUNCTION get_available_broadcast_requests_for_provider(
    p_provider_id uuid
)
RETURNS TABLE(
    request_id uuid,
    customer_name text,
    service_title text,
    service_description text,
    pickup_address text,
    distance_km numeric,
    estimated_arrival_minutes integer,
    estimated_price numeric,
    priority text,
    created_at timestamp with time zone,
    expires_at timestamp with time zone,
    time_remaining_minutes integer
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sr.id as request_id,
        (up.first_name || ' ' || up.last_name) as customer_name,
        sr.title as service_title,
        sr.description as service_description,
        sr.pickup_address,
        rb.distance_km,
        -- Estimate arrival time based on distance
        GREATEST(10, ROUND(rb.distance_km * 2))::integer as estimated_arrival_minutes,
        sr.estimated_price,
        sr.priority,
        sr.created_at,
        sr.broadcast_expires_at as expires_at,
        -- Calculate remaining time in minutes
        GREATEST(0, EXTRACT(EPOCH FROM (sr.broadcast_expires_at - now())) / 60)::integer as time_remaining_minutes
    FROM public.service_requests sr
    JOIN public.request_broadcasts rb ON rb.request_id = sr.id
    JOIN public.user_profiles up ON up.id = sr.customer_id
    WHERE 
        rb.provider_id = p_provider_id
        AND sr.broadcast_status = 'broadcasting'
        AND sr.broadcast_expires_at > now()
        AND rb.response_status = 'pending'
        AND rb.is_eligible = true
    ORDER BY 
        sr.priority DESC,
        rb.distance_km ASC,
        sr.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- ====================================================================
-- 8. CREATE TRIGGER TO AUTO-EXPIRE BROADCAST REQUESTS
-- ====================================================================

CREATE OR REPLACE FUNCTION auto_expire_broadcast_requests()
RETURNS trigger AS $$
BEGIN
    -- This function will be called periodically to clean up expired broadcasts
    UPDATE public.service_requests 
    SET broadcast_status = 'expired'
    WHERE broadcast_status = 'broadcasting'
    AND broadcast_expires_at < now();
    
    -- Update corresponding broadcast records
    UPDATE public.request_broadcasts 
    SET response_status = 'expired'
    WHERE response_status = 'pending'
    AND request_id IN (
        SELECT id FROM public.service_requests 
        WHERE broadcast_status = 'expired'
    );
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- ====================================================================
-- 9. CREATE FUNCTION TO UPDATE PROVIDER AVAILABILITY CACHE
-- ====================================================================

CREATE OR REPLACE FUNCTION update_provider_availability_cache()
RETURNS void AS $$
BEGIN
    -- Update shop availability
    INSERT INTO public.provider_availability_cache (
        provider_id, 
        provider_type, 
        is_available, 
        current_location_lat, 
        current_location_lng,
        service_radius_km,
        availability_status,
        operating_hours
    )
    SELECT 
        sp.id,
        'shop'::text,
        (s.is_active AND s.current_status = 'open'),
        s.latitude,
        s.longitude,
        s.service_radius,
        s.current_status,
        s.operating_hours
    FROM public.service_providers sp
    JOIN public.shops s ON s.owner_id = sp.user_id
    WHERE sp.is_verified = true
    ON CONFLICT (provider_id) DO UPDATE SET
        is_available = EXCLUDED.is_available,
        current_location_lat = EXCLUDED.current_location_lat,
        current_location_lng = EXCLUDED.current_location_lng,
        service_radius_km = EXCLUDED.service_radius_km,
        availability_status = EXCLUDED.availability_status,
        operating_hours = EXCLUDED.operating_hours,
        last_updated_at = now();
        
    -- Update independent mechanic availability
    INSERT INTO public.provider_availability_cache (
        provider_id, 
        provider_type, 
        is_available, 
        current_location_lat, 
        current_location_lng,
        service_radius_km,
        availability_status
    )
    SELECT 
        sp.id,
        'mechanic'::text,
        sp.is_available,
        sp.current_latitude,
        sp.current_longitude,
        sp.service_radius,
        COALESCE(mas.current_status, 'available')
    FROM public.service_providers sp
    LEFT JOIN public.mechanic_availability_status mas ON mas.mechanic_id = sp.user_id
    WHERE sp.is_verified = true 
    AND sp.shop_id IS NULL
    ON CONFLICT (provider_id) DO UPDATE SET
        is_available = EXCLUDED.is_available,
        current_location_lat = EXCLUDED.current_location_lat,
        current_location_lng = EXCLUDED.current_location_lng,
        service_radius_km = EXCLUDED.service_radius_km,
        availability_status = EXCLUDED.availability_status,
        last_updated_at = now();
END;
$$ LANGUAGE plpgsql;

-- ====================================================================
-- 10. CREATE INDEXES FOR PERFORMANCE
-- ====================================================================

-- Indexes for service_requests
CREATE INDEX IF NOT EXISTS idx_service_requests_broadcast_status ON public.service_requests(broadcast_status);
CREATE INDEX IF NOT EXISTS idx_service_requests_broadcast_expires_at ON public.service_requests(broadcast_expires_at);
CREATE INDEX IF NOT EXISTS idx_service_requests_location ON public.service_requests(pickup_latitude, pickup_longitude);
CREATE INDEX IF NOT EXISTS idx_service_requests_broadcast_active ON public.service_requests(broadcast_status, broadcast_expires_at) WHERE broadcast_status = 'broadcasting';

-- Indexes for better location queries
CREATE INDEX IF NOT EXISTS idx_shops_location ON public.shops(latitude, longitude) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_service_providers_location ON public.service_providers(current_latitude, current_longitude) WHERE is_available = true;

-- ====================================================================
-- 11. EXAMPLE USAGE
-- ====================================================================

/*
-- To create a broadcast request:
UPDATE public.service_requests 
SET request_type = 'broadcast',
    can_accept_by_any_mechanic = true,
    preferred_shop_id = NULL
WHERE id = 'your-request-id';

-- Then broadcast it:
SELECT broadcast_service_request('your-request-id', 25.0, 30);

-- For a provider to see available requests:
SELECT * FROM get_available_broadcast_requests_for_provider('provider-id');

-- For a provider to accept a request:
SELECT accept_broadcast_request('request-id', 'provider-id', 'mechanic-id');

-- To update availability cache (run periodically):
SELECT update_provider_availability_cache();
*/

-- ====================================================================
-- NOTES FOR IMPLEMENTATION:
-- ====================================================================
/*
1. Frontend Integration:
   - Customer selects "Any Available Mechanic" option
   - System calls broadcast_service_request()
   - All eligible providers get push notifications
   - First to accept gets the job

2. Real-time Updates:
   - Use Supabase real-time subscriptions on request_broadcasts table
   - Providers see live list of available requests
   - Request disappears when someone accepts it

3. Notification System:
   - Push notifications to provider apps
   - Include distance, estimated pay, service type
   - Countdown timer showing time remaining

4. Race Condition Protection:
   - accept_broadcast_request() uses proper locking
   - Only one provider can accept each request
   - Others automatically get "already taken" response

5. Performance Optimization:
   - Location-based indexing for fast distance queries
   - Cache provider availability for quick filtering
   - Clean up expired requests regularly
*/