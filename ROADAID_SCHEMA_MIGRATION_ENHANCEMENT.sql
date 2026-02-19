-- =====================================================
-- ROADAID DATABASE SCHEMA ENHANCEMENT & MIGRATION
-- Enhances existing schema with PostGIS and improved broadcast system
-- Safe migration that preserves existing data and structure
-- =====================================================

-- Enable PostGIS extension for spatial operations
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- SCHEMA ENHANCEMENT: ADD MISSING COLUMNS FOR SPATIAL OPERATIONS
-- =====================================================

-- Add location geometry column to service_providers if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'service_providers' 
        AND column_name = 'location'
    ) THEN
        ALTER TABLE public.service_providers 
        ADD COLUMN location geometry(Point, 4326);
    END IF;
END $$;

-- Add location geometry column to service_requests if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'service_requests' 
        AND column_name = 'location'
    ) THEN
        ALTER TABLE public.service_requests 
        ADD COLUMN location geometry(Point, 4326);
    END IF;
END $$;

-- Add location geometry column to user_profiles for mechanics if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_profiles' 
        AND column_name = 'location'
    ) THEN
        ALTER TABLE public.user_profiles 
        ADD COLUMN location geometry(Point, 4326);
    END IF;
END $$;

-- Add business_address to service_providers if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'service_providers' 
        AND column_name = 'business_address'
    ) THEN
        ALTER TABLE public.service_providers 
        ADD COLUMN business_address text;
    END IF;
END $$;

-- Add pickup_address to service_requests if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'service_requests' 
        AND column_name = 'pickup_address'
    ) THEN
        ALTER TABLE public.service_requests 
        ADD COLUMN pickup_address text;
    END IF;
END $$;

-- =====================================================
-- UPDATE EXISTING DATA TO POPULATE GEOMETRY COLUMNS
-- =====================================================

-- Update service_providers location from existing lat/lng data
UPDATE public.service_providers 
SET location = ST_SetSRID(ST_MakePoint(current_longitude, current_latitude), 4326)
WHERE current_latitude IS NOT NULL 
AND current_longitude IS NOT NULL 
AND location IS NULL;

-- Update service_requests location from existing pickup coordinates
UPDATE public.service_requests 
SET location = ST_SetSRID(ST_MakePoint(pickup_longitude, pickup_latitude), 4326)
WHERE pickup_latitude IS NOT NULL 
AND pickup_longitude IS NOT NULL 
AND location IS NULL;

-- Update user_profiles (mechanics) location from existing coordinates
UPDATE public.user_profiles 
SET location = ST_SetSRID(ST_MakePoint(current_longitude, current_latitude), 4326)
WHERE current_latitude IS NOT NULL 
AND current_longitude IS NOT NULL 
AND location IS NULL;

-- =====================================================
-- CREATE SPATIAL INDEXES FOR PERFORMANCE
-- =====================================================

-- Create spatial indexes if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'service_providers' 
        AND indexname = 'idx_service_providers_location'
    ) THEN
        CREATE INDEX idx_service_providers_location 
        ON public.service_providers USING GIST (location);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'service_requests' 
        AND indexname = 'idx_service_requests_location'
    ) THEN
        CREATE INDEX idx_service_requests_location 
        ON public.service_requests USING GIST (location);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'user_profiles' 
        AND indexname = 'idx_user_profiles_location'
    ) THEN
        CREATE INDEX idx_user_profiles_location 
        ON public.user_profiles USING GIST (location);
    END IF;
END $$;

-- =====================================================
-- CREATE TRIGGERS TO AUTO-UPDATE GEOMETRY
-- =====================================================

-- Function to update geometry from lat/lng coordinates
CREATE OR REPLACE FUNCTION update_location_geometry()
RETURNS TRIGGER AS $$
BEGIN
    -- For service_providers table
    IF TG_TABLE_NAME = 'service_providers' THEN
        IF NEW.current_latitude IS NOT NULL AND NEW.current_longitude IS NOT NULL THEN
            NEW.location = ST_SetSRID(ST_MakePoint(NEW.current_longitude, NEW.current_latitude), 4326);
        END IF;
        NEW.updated_at = now();
    END IF;
    
    -- For service_requests table
    IF TG_TABLE_NAME = 'service_requests' THEN
        IF NEW.pickup_latitude IS NOT NULL AND NEW.pickup_longitude IS NOT NULL THEN
            NEW.location = ST_SetSRID(ST_MakePoint(NEW.pickup_longitude, NEW.pickup_latitude), 4326);
        END IF;
        NEW.updated_at = now();
    END IF;
    
    -- For user_profiles table
    IF TG_TABLE_NAME = 'user_profiles' THEN
        IF NEW.current_latitude IS NOT NULL AND NEW.current_longitude IS NOT NULL THEN
            NEW.location = ST_SetSRID(ST_MakePoint(NEW.current_longitude, NEW.current_latitude), 4326);
        END IF;
        NEW.updated_at = now();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers if they don't exist
DROP TRIGGER IF EXISTS trg_service_providers_location ON public.service_providers;
CREATE TRIGGER trg_service_providers_location
    BEFORE INSERT OR UPDATE ON public.service_providers
    FOR EACH ROW EXECUTE FUNCTION update_location_geometry();

DROP TRIGGER IF EXISTS trg_service_requests_location ON public.service_requests;
CREATE TRIGGER trg_service_requests_location
    BEFORE INSERT OR UPDATE ON public.service_requests
    FOR EACH ROW EXECUTE FUNCTION update_location_geometry();

DROP TRIGGER IF EXISTS trg_user_profiles_location ON public.user_profiles;
CREATE TRIGGER trg_user_profiles_location
    BEFORE INSERT OR UPDATE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_location_geometry();

-- =====================================================
-- ENHANCED BROADCAST FUNCTIONS FOR EXISTING SCHEMA
-- =====================================================

-- 1. Get Available Mechanics in a Shop (Enhanced)
CREATE OR REPLACE FUNCTION get_available_mechanics_in_shop(
    shop_id_param uuid
)
RETURNS TABLE (
    mechanic_id uuid,
    mechanic_name text,
    status text,
    phone_number text,
    rating numeric,
    total_completed_jobs integer,
    distance_km numeric
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        up.id,
        CONCAT(up.first_name, ' ', up.last_name),
        mas.current_status,
        up.phone_number,
        COALESCE(sp.rating, 0.0),
        COALESCE(sp.total_services, 0),
        0.0 as distance_km -- Distance not relevant within same shop
    FROM public.user_profiles up
    LEFT JOIN public.mechanic_availability_status mas ON mas.mechanic_id = up.id
    LEFT JOIN public.service_providers sp ON sp.user_id = up.id
    WHERE up.user_type = 'mechanic'
    AND up.shop_id = shop_id_param
    AND COALESCE(mas.current_status, 'available') = 'available'
    AND COALESCE(mas.is_accepting_requests, true) = true
    AND mas.current_request_id IS NULL
    AND up.is_available = true
    AND up.status = 'active'
    ORDER BY COALESCE(sp.rating, 0.0) DESC, COALESCE(sp.total_services, 0) DESC;
    
    -- Check if no mechanics found
    IF NOT FOUND THEN
        RAISE NOTICE 'No available mechanics in this shop';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 2. Get Nearest Available Mechanic (PostGIS Enhanced)
CREATE OR REPLACE FUNCTION get_nearest_available_mechanic(
    customer_lat numeric,
    customer_lng numeric,
    max_distance_km numeric DEFAULT 50.0
)
RETURNS TABLE (
    mechanic_id uuid,
    mechanic_name text,
    shop_id uuid,
    shop_name text,
    status text,
    distance_km numeric,
    estimated_arrival_minutes integer,
    rating numeric,
    phone_number text
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        up.id,
        CONCAT(up.first_name, ' ', up.last_name),
        up.shop_id,
        COALESCE(s.shop_name, 'Independent') as shop_name,
        COALESCE(mas.current_status, 'available'),
        ROUND(
            CASE 
                WHEN up.location IS NOT NULL THEN
                    ST_Distance(
                        ST_SetSRID(ST_MakePoint(customer_lng, customer_lat), 4326),
                        up.location
                    ) / 1000
                ELSE
                    COALESCE(
                        sqrt(
                            power(69.1 * (up.current_latitude - customer_lat), 2) +
                            power(69.1 * (customer_lng - up.current_longitude) * cos(customer_lat / 57.3), 2)
                        ) * 1.60934, 999.9
                    )
            END, 2
        ) as distance_km,
        ROUND(
            CASE 
                WHEN up.location IS NOT NULL THEN
                    (ST_Distance(
                        ST_SetSRID(ST_MakePoint(customer_lng, customer_lat), 4326),
                        up.location
                    ) / 1000) * 2 + 10
                ELSE
                    COALESCE(
                        sqrt(
                            power(69.1 * (up.current_latitude - customer_lat), 2) +
                            power(69.1 * (customer_lng - up.current_longitude) * cos(customer_lat / 57.3), 2)
                        ) * 1.60934 * 2 + 10, 60
                    )
            END
        )::integer as estimated_arrival_minutes,
        COALESCE(sp.rating, 0.0),
        up.phone_number
    FROM public.user_profiles up
    LEFT JOIN public.mechanic_availability_status mas ON mas.mechanic_id = up.id
    LEFT JOIN public.service_providers sp ON sp.user_id = up.id
    LEFT JOIN public.shops s ON s.id = up.shop_id
    WHERE up.user_type = 'mechanic'
    AND COALESCE(mas.current_status, 'available') = 'available'
    AND COALESCE(mas.is_accepting_requests, true) = true
    AND mas.current_request_id IS NULL
    AND up.is_available = true
    AND up.status = 'active'
    AND (
        up.current_latitude IS NOT NULL 
        AND up.current_longitude IS NOT NULL
    )
    AND (
        CASE 
            WHEN up.location IS NOT NULL THEN
                ST_DWithin(
                    ST_SetSRID(ST_MakePoint(customer_lng, customer_lat), 4326),
                    up.location,
                    max_distance_km * 1000
                )
            ELSE
                sqrt(
                    power(69.1 * (up.current_latitude - customer_lat), 2) +
                    power(69.1 * (customer_lng - up.current_longitude) * cos(customer_lat / 57.3), 2)
                ) * 1.60934 <= max_distance_km
        END
    )
    ORDER BY distance_km ASC, COALESCE(sp.rating, 0.0) DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- 3. Atomic Request Acceptance (Enhanced for existing schema)
CREATE OR REPLACE FUNCTION accept_service_request(
    request_id_param uuid,
    mechanic_id_param uuid
)
RETURNS TABLE (
    success boolean,
    message text,
    request_data jsonb
) AS $$
DECLARE
    updated_request public.service_requests%ROWTYPE;
    mechanic_available boolean;
    current_status text;
BEGIN
    -- Check if mechanic is available
    SELECT 
        CASE 
            WHEN mas.current_status = 'available' 
            AND COALESCE(mas.is_accepting_requests, true) = true 
            AND mas.current_request_id IS NULL 
            AND up.is_available = true 
            AND up.status = 'active'
            THEN true 
            ELSE false 
        END,
        COALESCE(mas.current_status, 'offline')
    INTO mechanic_available, current_status
    FROM public.user_profiles up
    LEFT JOIN public.mechanic_availability_status mas ON mas.mechanic_id = up.id
    WHERE up.id = mechanic_id_param;
    
    IF NOT mechanic_available THEN
        RETURN QUERY SELECT false, 'Mechanic is not available (Status: ' || current_status || ')', NULL::jsonb;
        RETURN;
    END IF;
    
    -- Atomic update: accept request only if still pending
    UPDATE public.service_requests 
    SET 
        status = 'accepted',
        accepted_by = mechanic_id_param,
        accepted_at = now(),
        assigned_mechanic_id = mechanic_id_param
    WHERE id = request_id_param 
    AND status IN ('pending', 'ready_to_assign')
    RETURNING * INTO updated_request;
    
    -- Check if update was successful
    IF updated_request.id IS NULL THEN
        RETURN QUERY SELECT false, 'Request is no longer available or already accepted', NULL::jsonb;
        RETURN;
    END IF;
    
    -- Update mechanic status
    UPDATE public.mechanic_availability_status
    SET 
        current_status = 'busy',
        current_request_id = request_id_param,
        last_status_update = now()
    WHERE mechanic_id = mechanic_id_param;
    
    -- Insert into mechanic_availability_status if not exists
    INSERT INTO public.mechanic_availability_status (
        mechanic_id, 
        current_status, 
        current_request_id,
        last_status_update
    )
    SELECT 
        mechanic_id_param, 
        'busy', 
        request_id_param,
        now()
    WHERE NOT EXISTS (
        SELECT 1 FROM public.mechanic_availability_status 
        WHERE mechanic_id = mechanic_id_param
    );
    
    -- Update request_broadcasts table
    UPDATE public.request_broadcasts
    SET 
        response_status = 'accepted',
        responded_at = now()
    WHERE request_id = request_id_param 
    AND mechanic_id = mechanic_id_param;
    
    -- Return success with request data
    RETURN QUERY SELECT 
        true, 
        'Request accepted successfully',
        row_to_json(updated_request)::jsonb;
        
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT false, 'Error accepting request: ' || SQLERRM, NULL::jsonb;
END;
$$ LANGUAGE plpgsql;

-- 4. Enhanced Broadcast Function for existing schema
CREATE OR REPLACE FUNCTION broadcast_service_request(
    request_id_param uuid,
    max_distance_km numeric DEFAULT 20.0,
    max_mechanics integer DEFAULT 10
)
RETURNS TABLE (
    success boolean,
    mechanics_notified integer,
    message text
) AS $$
DECLARE
    request_location geometry;
    request_lat numeric;
    request_lng numeric;
    mechanic_count integer := 0;
    request_record public.service_requests%ROWTYPE;
BEGIN
    -- Get request details
    SELECT * INTO request_record
    FROM public.service_requests
    WHERE id = request_id_param;
    
    IF request_record.id IS NULL THEN
        RETURN QUERY SELECT false, 0, 'Service request not found';
        RETURN;
    END IF;
    
    request_lat := request_record.pickup_latitude;
    request_lng := request_record.pickup_longitude;
    request_location := COALESCE(
        request_record.location,
        ST_SetSRID(ST_MakePoint(request_lng, request_lat), 4326)
    );
    
    -- Clear existing broadcast entries for this request
    DELETE FROM public.request_broadcasts WHERE request_id = request_id_param;
    
    -- Insert broadcast entries for nearby available mechanics
    INSERT INTO public.request_broadcasts (
        request_id, 
        provider_id,
        provider_type,
        mechanic_id, 
        shop_id,
        distance_km, 
        notification_sent_at,
        is_eligible
    )
    SELECT 
        request_id_param,
        COALESCE(sp.id, up.id), -- Use service_provider id if exists, otherwise user_profile id
        'mechanic',
        up.id,
        up.shop_id,
        ROUND(
            CASE 
                WHEN up.location IS NOT NULL THEN
                    ST_Distance(request_location, up.location) / 1000
                ELSE
                    sqrt(
                        power(69.1 * (up.current_latitude - request_lat), 2) +
                        power(69.1 * (request_lng - up.current_longitude) * cos(request_lat / 57.3), 2)
                    ) * 1.60934
            END, 2
        ),
        now(),
        true
    FROM public.user_profiles up
    LEFT JOIN public.mechanic_availability_status mas ON mas.mechanic_id = up.id
    LEFT JOIN public.service_providers sp ON sp.user_id = up.id
    WHERE up.user_type = 'mechanic'
    AND COALESCE(mas.current_status, 'available') = 'available'
    AND COALESCE(mas.is_accepting_requests, true) = true
    AND mas.current_request_id IS NULL
    AND up.is_available = true
    AND up.status = 'active'
    AND up.current_latitude IS NOT NULL 
    AND up.current_longitude IS NOT NULL
    AND (
        CASE 
            WHEN up.location IS NOT NULL THEN
                ST_DWithin(request_location, up.location, max_distance_km * 1000)
            ELSE
                sqrt(
                    power(69.1 * (up.current_latitude - request_lat), 2) +
                    power(69.1 * (request_lng - up.current_longitude) * cos(request_lat / 57.3), 2)
                ) * 1.60934 <= max_distance_km
        END
    )
    ORDER BY 
        CASE 
            WHEN up.location IS NOT NULL THEN
                ST_Distance(request_location, up.location)
            ELSE
                sqrt(
                    power(69.1 * (up.current_latitude - request_lat), 2) +
                    power(69.1 * (request_lng - up.current_longitude) * cos(request_lat / 57.3), 2)
                ) * 1.60934 * 1000
        END
    LIMIT max_mechanics;
    
    GET DIAGNOSTICS mechanic_count = ROW_COUNT;
    
    -- Update request status
    UPDATE public.service_requests
    SET 
        status = CASE WHEN mechanic_count > 0 THEN 'ready_to_assign' ELSE 'pending' END,
        broadcast_started_at = now(),
        broadcast_expires_at = now() + interval '30 minutes',
        mechanics_notified_count = mechanic_count,
        is_broadcast_request = true
    WHERE id = request_id_param;
    
    RETURN QUERY SELECT 
        true, 
        mechanic_count, 
        CASE 
            WHEN mechanic_count > 0 THEN 'Request broadcasted to ' || mechanic_count || ' mechanics'
            ELSE 'No available mechanics found within ' || max_distance_km || ' km'
        END;
        
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT false, 0, 'Error broadcasting request: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- HELPER FUNCTION: Calculate Distance Between Two Points
-- =====================================================

CREATE OR REPLACE FUNCTION calculate_distance_km(
    lat1 numeric, lng1 numeric,
    lat2 numeric, lng2 numeric
)
RETURNS numeric AS $$
BEGIN
    -- Use PostGIS if available, otherwise use Haversine formula
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis') THEN
        RETURN ST_Distance(
            ST_SetSRID(ST_MakePoint(lng1, lat1), 4326),
            ST_SetSRID(ST_MakePoint(lng2, lat2), 4326)
        ) / 1000; -- Convert meters to kilometers
    ELSE
        -- Haversine formula fallback
        RETURN sqrt(
            power(69.1 * (lat2 - lat1), 2) +
            power(69.1 * (lng1 - lng2) * cos(lat1 / 57.3), 2)
        ) * 1.60934; -- Convert miles to km
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- VIEW: Available Mechanics with Enhanced Location Info
-- =====================================================

CREATE OR REPLACE VIEW available_mechanics_with_location AS
SELECT 
    up.id,
    CONCAT(up.first_name, ' ', up.last_name) as mechanic_name,
    COALESCE(mas.current_status, 'available') as status,
    up.shop_id,
    s.shop_name,
    up.current_latitude,
    up.current_longitude,
    up.phone_number,
    COALESCE(sp.rating, 0.0) as rating,
    COALESCE(sp.total_services, 0) as total_completed_jobs,
    COALESCE(mas.is_accepting_requests, true) as is_accepting_requests,
    up.location
FROM public.user_profiles up
LEFT JOIN public.mechanic_availability_status mas ON mas.mechanic_id = up.id
LEFT JOIN public.service_providers sp ON sp.user_id = up.id
LEFT JOIN public.shops s ON s.id = up.shop_id
WHERE up.user_type = 'mechanic'
AND COALESCE(mas.current_status, 'available') = 'available' 
AND COALESCE(mas.is_accepting_requests, true) = true 
AND mas.current_request_id IS NULL
AND up.is_available = true
AND up.status = 'active';

-- =====================================================
-- ADDITIONAL PERFORMANCE INDEXES
-- =====================================================

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_user_profiles_mechanic_availability 
ON public.user_profiles (user_type, is_available, status, current_latitude, current_longitude) 
WHERE user_type = 'mechanic';

CREATE INDEX IF NOT EXISTS idx_service_requests_broadcast_status 
ON public.service_requests (status, is_broadcast_request, broadcast_expires_at);

CREATE INDEX IF NOT EXISTS idx_request_broadcasts_response 
ON public.request_broadcasts (response_status, notification_sent_at, responded_at) 
WHERE response_status = 'pending';

CREATE INDEX IF NOT EXISTS idx_mechanic_availability_status_lookup
ON public.mechanic_availability_status (current_status, is_accepting_requests, current_request_id)
WHERE current_status = 'available';

-- =====================================================
-- SAMPLE USAGE QUERIES FOR TESTING
-- =====================================================

/*
-- Test the enhanced functions:

-- 1. Get available mechanics in a specific shop
SELECT * FROM get_available_mechanics_in_shop('your-shop-uuid-here');

-- 2. Find nearest available mechanic (Manila coordinates example)
SELECT * FROM get_nearest_available_mechanic(14.5995, 120.9842, 25.0);

-- 3. Accept a service request (atomic operation)
SELECT * FROM accept_service_request('request-uuid', 'mechanic-uuid');

-- 4. Broadcast request to nearby mechanics
SELECT * FROM broadcast_service_request('request-uuid', 15.0, 5);

-- 5. Get all pending broadcasts for a mechanic
SELECT 
    sr.title,
    sr.description,
    rb.distance_km,
    rb.notification_sent_at,
    EXTRACT(MINUTES FROM (now() - rb.notification_sent_at)) as minutes_ago
FROM public.service_requests sr
JOIN public.request_broadcasts rb ON rb.request_id = sr.id
WHERE rb.mechanic_id = 'mechanic-uuid'
AND sr.status IN ('pending', 'ready_to_assign')
AND rb.response_status = 'pending'
ORDER BY rb.distance_km;

-- 6. Search for shops within radius (enhanced with PostGIS)
SELECT 
    s.*,
    calculate_distance_km(s.latitude, s.longitude, 14.5995, 120.9842) as distance_km
FROM public.shops s
WHERE s.is_active = true
AND calculate_distance_km(s.latitude, s.longitude, 14.5995, 120.9842) <= 10
ORDER BY distance_km;
*/

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '🚀 ROADAID SCHEMA ENHANCEMENT COMPLETED SUCCESSFULLY!';
    RAISE NOTICE '';
    RAISE NOTICE 'MIGRATION FEATURES:';
    RAISE NOTICE '✅ PostGIS spatial operations added (compatible with existing schema)';
    RAISE NOTICE '✅ Enhanced broadcast system with distance calculations';
    RAISE NOTICE '✅ Atomic request acceptance with race condition protection';
    RAISE NOTICE '✅ Preserved all existing data and table structure';
    RAISE NOTICE '✅ Added spatial indexes for high-performance queries';
    RAISE NOTICE '✅ Enhanced mechanic availability tracking';
    RAISE NOTICE '';
    RAISE NOTICE 'BROADCAST ISSUE SHOULD NOW BE FIXED!';
    RAISE NOTICE 'All mechanics within range will now receive service requests.';
END $$;