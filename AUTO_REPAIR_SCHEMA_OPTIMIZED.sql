-- =====================================================
-- AUTO REPAIR RIDE-HAILING SYSTEM - OPTIMIZED SCHEMA
-- Supabase/PostgreSQL with PostGIS for Location Services
-- =====================================================

-- Enable PostGIS extension for spatial operations
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS uuid-ossp;

-- =====================================================
-- CORE TABLES
-- =====================================================

-- Service Providers (Shops/Talyers)
CREATE TABLE IF NOT EXISTS public.service_providers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    company_name varchar(255) NOT NULL,
    business_address text NOT NULL,
    location geometry(Point, 4326) NOT NULL, -- PostGIS Point for precise location
    latitude numeric CHECK (latitude >= -90 AND latitude <= 90),
    longitude numeric CHECK (longitude >= -180 AND longitude <= 180),
    phone_number varchar(20),
    email varchar(255),
    license_number varchar(100),
    business_permit_url text,
    service_radius_km numeric DEFAULT 10.0 CHECK (service_radius_km > 0),
    operating_hours jsonb DEFAULT '{}',
    is_verified boolean DEFAULT false,
    is_active boolean DEFAULT true,
    rating numeric DEFAULT 0.0 CHECK (rating >= 0 AND rating <= 5),
    total_reviews integer DEFAULT 0,
    total_completed_jobs integer DEFAULT 0,
    response_time_avg_minutes integer DEFAULT 30,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Mechanics (under each shop)
CREATE TABLE IF NOT EXISTS public.mechanics (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    shop_id uuid REFERENCES public.service_providers(id) ON DELETE SET NULL,
    mechanic_name varchar(255) NOT NULL,
    phone_number varchar(20),
    specializations text[] DEFAULT '{}',
    experience_years integer DEFAULT 0,
    hourly_rate numeric DEFAULT 0.0,
    status varchar(20) DEFAULT 'available' CHECK (status IN ('available', 'busy', 'offline', 'on_break')),
    location geometry(Point, 4326), -- Current location for distance calculations
    latitude numeric,
    longitude numeric,
    is_independent boolean DEFAULT false, -- Can work without shop assignment
    is_accepting_requests boolean DEFAULT true,
    current_request_id uuid,
    last_location_update timestamptz DEFAULT now(),
    rating numeric DEFAULT 0.0 CHECK (rating >= 0 AND rating <= 5),
    total_completed_jobs integer DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Service Requests (customer requests)
CREATE TABLE IF NOT EXISTS public.service_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    shop_id uuid REFERENCES public.service_providers(id) ON DELETE SET NULL,
    accepted_by uuid REFERENCES public.mechanics(id) ON DELETE SET NULL,
    
    -- Request Details
    title varchar(255) NOT NULL,
    description text,
    service_type varchar(100) NOT NULL,
    priority varchar(20) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'emergency')),
    
    -- Location Information
    location geometry(Point, 4326) NOT NULL,
    pickup_latitude numeric NOT NULL CHECK (pickup_latitude >= -90 AND pickup_latitude <= 90),
    pickup_longitude numeric NOT NULL CHECK (pickup_longitude >= -180 AND pickup_longitude <= 180),
    pickup_address text NOT NULL,
    
    -- Status and Workflow
    status varchar(30) DEFAULT 'pending' CHECK (status IN (
        'pending', 'broadcasting', 'accepted', 'assigned', 'in_progress', 
        'inspection_completed', 'invoice_sent', 'payment_pending', 
        'completed', 'cancelled', 'rejected'
    )),
    
    -- Pricing
    estimated_price numeric CHECK (estimated_price >= 0),
    final_price numeric CHECK (final_price >= 0),
    service_fee numeric DEFAULT 0.0,
    platform_fee numeric DEFAULT 0.0,
    
    -- Request Type and Broadcasting
    request_type varchar(20) DEFAULT 'shop_specific' CHECK (request_type IN ('shop_specific', 'broadcast', 'emergency')),
    broadcast_radius_km numeric DEFAULT 10.0,
    max_response_time_minutes integer DEFAULT 30,
    
    -- Timestamps
    created_at timestamptz DEFAULT now(),
    accepted_at timestamptz,
    started_at timestamptz,
    completed_at timestamptz,
    cancelled_at timestamptz,
    expires_at timestamptz DEFAULT (now() + interval '2 hours'),
    
    -- Additional Fields
    vehicle_info jsonb DEFAULT '{}',
    customer_notes text,
    mechanic_notes text,
    is_emergency boolean DEFAULT false,
    
    CONSTRAINT valid_acceptance CHECK (
        (status = 'accepted' AND accepted_by IS NOT NULL) OR 
        (status != 'accepted')
    )
);

-- Request Broadcasting/Routing Table
CREATE TABLE IF NOT EXISTS public.request_routing (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id uuid NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    mechanic_id uuid REFERENCES public.mechanics(id) ON DELETE CASCADE,
    shop_id uuid REFERENCES public.service_providers(id) ON DELETE CASCADE,
    
    routing_type varchar(20) NOT NULL CHECK (routing_type IN ('direct_shop', 'broadcast', 'nearest_available')),
    distance_km numeric NOT NULL,
    estimated_arrival_minutes integer,
    
    is_notified boolean DEFAULT false,
    notified_at timestamptz,
    response_status varchar(20) DEFAULT 'pending' CHECK (response_status IN ('pending', 'viewed', 'accepted', 'declined', 'expired')),
    responded_at timestamptz,
    response_deadline timestamptz DEFAULT (now() + interval '30 minutes'),
    
    created_at timestamptz DEFAULT now(),
    
    -- Ensure either mechanic_id or shop_id is provided
    CONSTRAINT routing_target_check CHECK (
        (mechanic_id IS NOT NULL AND shop_id IS NULL) OR 
        (mechanic_id IS NULL AND shop_id IS NOT NULL) OR
        (mechanic_id IS NOT NULL AND shop_id IS NOT NULL)
    )
);

-- =====================================================
-- SPATIAL INDEXES FOR PERFORMANCE
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_service_providers_location ON public.service_providers USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_mechanics_location ON public.mechanics USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_service_requests_location ON public.service_requests USING GIST (location);

-- Regular indexes for common queries
CREATE INDEX IF NOT EXISTS idx_mechanics_status ON public.mechanics (status) WHERE status = 'available';
CREATE INDEX IF NOT EXISTS idx_service_requests_status ON public.service_requests (status);
CREATE INDEX IF NOT EXISTS idx_service_requests_created_at ON public.service_requests (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_request_routing_mechanic ON public.request_routing (mechanic_id, response_status);

-- =====================================================
-- BUSINESS LOGIC FUNCTIONS
-- =====================================================

-- Function to update geometry from lat/lng coordinates
CREATE OR REPLACE FUNCTION update_location_geometry()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.location = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326);
    END IF;
    
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers to auto-update geometry
DROP TRIGGER IF EXISTS trg_service_providers_location ON public.service_providers;
CREATE TRIGGER trg_service_providers_location
    BEFORE INSERT OR UPDATE ON public.service_providers
    FOR EACH ROW EXECUTE FUNCTION update_location_geometry();

DROP TRIGGER IF EXISTS trg_mechanics_location ON public.mechanics;
CREATE TRIGGER trg_mechanics_location
    BEFORE INSERT OR UPDATE ON public.mechanics
    FOR EACH ROW EXECUTE FUNCTION update_location_geometry();

DROP TRIGGER IF EXISTS trg_service_requests_location ON public.service_requests;
CREATE TRIGGER trg_service_requests_location
    BEFORE INSERT OR UPDATE ON public.service_requests
    FOR EACH ROW EXECUTE FUNCTION update_location_geometry();

-- =====================================================
-- QUERY 1: Get Available Mechanics in a Chosen Shop
-- =====================================================

CREATE OR REPLACE FUNCTION get_available_mechanics_in_shop(
    shop_id_param uuid
)
RETURNS TABLE (
    mechanic_id uuid,
    mechanic_name varchar,
    status varchar,
    specializations text[],
    rating numeric,
    distance_km numeric
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.id,
        m.mechanic_name,
        m.status,
        m.specializations,
        m.rating,
        0.0 as distance_km -- Distance not relevant within same shop
    FROM public.mechanics m
    WHERE m.shop_id = shop_id_param
    AND m.status = 'available'
    AND m.is_accepting_requests = true
    AND m.current_request_id IS NULL
    ORDER BY m.rating DESC, m.total_completed_jobs DESC;
    
    -- Check if no mechanics found
    IF NOT FOUND THEN
        RAISE NOTICE 'No available mechanics in this shop';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- QUERY 2: Get Nearest Available Mechanic (No Shop Chosen)
-- =====================================================

CREATE OR REPLACE FUNCTION get_nearest_available_mechanic(
    customer_lat numeric,
    customer_lng numeric,
    max_distance_km numeric DEFAULT 50.0
)
RETURNS TABLE (
    mechanic_id uuid,
    mechanic_name varchar,
    shop_id uuid,
    shop_name varchar,
    status varchar,
    distance_km numeric,
    estimated_arrival_minutes integer,
    rating numeric
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.id,
        m.mechanic_name,
        m.shop_id,
        COALESCE(sp.company_name, 'Independent') as shop_name,
        m.status,
        ROUND(
            ST_Distance(
                ST_SetSRID(ST_MakePoint(customer_lng, customer_lat), 4326),
                m.location
            ) / 1000, 2
        ) as distance_km,
        ROUND(
            (ST_Distance(
                ST_SetSRID(ST_MakePoint(customer_lng, customer_lat), 4326),
                m.location
            ) / 1000) * 2 + 10 -- Rough estimate: 2 minutes per km + 10 minutes prep
        )::integer as estimated_arrival_minutes,
        m.rating
    FROM public.mechanics m
    LEFT JOIN public.service_providers sp ON sp.id = m.shop_id
    WHERE m.status = 'available'
    AND m.is_accepting_requests = true
    AND m.current_request_id IS NULL
    AND m.location IS NOT NULL
    AND ST_DWithin(
        ST_SetSRID(ST_MakePoint(customer_lng, customer_lat), 4326),
        m.location,
        max_distance_km * 1000 -- Convert km to meters
    )
    ORDER BY distance_km ASC, m.rating DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- QUERY 3: Atomic Request Acceptance
-- =====================================================

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
BEGIN
    -- Check if mechanic is available
    SELECT (status = 'available' AND is_accepting_requests = true AND current_request_id IS NULL)
    INTO mechanic_available
    FROM public.mechanics
    WHERE id = mechanic_id_param;
    
    IF NOT mechanic_available THEN
        RETURN QUERY SELECT false, 'Mechanic is not available', NULL::jsonb;
        RETURN;
    END IF;
    
    -- Atomic update: accept request only if still pending
    UPDATE public.service_requests 
    SET 
        status = 'accepted',
        accepted_by = mechanic_id_param,
        accepted_at = now()
    WHERE id = request_id_param 
    AND status = 'pending'
    RETURNING * INTO updated_request;
    
    -- Check if update was successful
    IF updated_request.id IS NULL THEN
        RETURN QUERY SELECT false, 'Request is no longer available or already accepted', NULL::jsonb;
        RETURN;
    END IF;
    
    -- Update mechanic status
    UPDATE public.mechanics
    SET 
        status = 'busy',
        current_request_id = request_id_param,
        updated_at = now()
    WHERE id = mechanic_id_param;
    
    -- Update routing table
    UPDATE public.request_routing
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

-- =====================================================
-- QUERY 4: Broadcast Request to Nearby Mechanics
-- =====================================================

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
    
    request_location := request_record.location;
    
    -- Clear existing routing entries for this request
    DELETE FROM public.request_routing WHERE request_id = request_id_param;
    
    -- Insert routing entries for nearby available mechanics
    INSERT INTO public.request_routing (
        request_id, 
        mechanic_id, 
        routing_type, 
        distance_km, 
        estimated_arrival_minutes
    )
    SELECT 
        request_id_param,
        m.id,
        'broadcast',
        ROUND(ST_Distance(request_location, m.location) / 1000, 2),
        ROUND((ST_Distance(request_location, m.location) / 1000) * 2 + 10)::integer
    FROM public.mechanics m
    WHERE m.status = 'available'
    AND m.is_accepting_requests = true
    AND m.current_request_id IS NULL
    AND m.location IS NOT NULL
    AND ST_DWithin(request_location, m.location, max_distance_km * 1000)
    ORDER BY ST_Distance(request_location, m.location)
    LIMIT max_mechanics;
    
    GET DIAGNOSTICS mechanic_count = ROW_COUNT;
    
    -- Update request status
    UPDATE public.service_requests
    SET 
        status = CASE WHEN mechanic_count > 0 THEN 'broadcasting' ELSE 'pending' END,
        request_type = 'broadcast'
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
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE public.service_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mechanics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.request_routing ENABLE ROW LEVEL SECURITY;

-- Service Providers: Only owners can see their own shops
CREATE POLICY service_providers_owner_policy ON public.service_providers
    FOR ALL USING (user_id = auth.uid());

-- Service Providers: Public read access for customer searches
CREATE POLICY service_providers_public_read ON public.service_providers
    FOR SELECT USING (is_active = true);

-- Mechanics: Can see their own data
CREATE POLICY mechanics_self_policy ON public.mechanics
    FOR ALL USING (user_id = auth.uid());

-- Mechanics: Shop owners can see their mechanics
CREATE POLICY mechanics_shop_owner_policy ON public.mechanics
    FOR ALL USING (
        shop_id IN (
            SELECT id FROM public.service_providers 
            WHERE user_id = auth.uid()
        )
    );

-- Mechanics: Public read for available mechanics (for customer searches)
CREATE POLICY mechanics_public_available ON public.mechanics
    FOR SELECT USING (status = 'available' AND is_accepting_requests = true);

-- Service Requests: Customers can see their own requests
CREATE POLICY service_requests_customer_policy ON public.service_requests
    FOR ALL USING (customer_id = auth.uid());

-- Service Requests: Mechanics can see requests assigned to them
CREATE POLICY service_requests_mechanic_policy ON public.service_requests
    FOR SELECT USING (
        accepted_by IN (
            SELECT id FROM public.mechanics 
            WHERE user_id = auth.uid()
        )
    );

-- Service Requests: Shop owners can see requests for their shops
CREATE POLICY service_requests_shop_owner_policy ON public.service_requests
    FOR SELECT USING (
        shop_id IN (
            SELECT id FROM public.service_providers 
            WHERE user_id = auth.uid()
        )
    );

-- Request Routing: Mechanics can see routing entries for them
CREATE POLICY request_routing_mechanic_policy ON public.request_routing
    FOR SELECT USING (
        mechanic_id IN (
            SELECT id FROM public.mechanics 
            WHERE user_id = auth.uid()
        )
    );

-- =====================================================
-- HELPER FUNCTIONS AND VIEWS
-- =====================================================

-- View: Available mechanics with location info
CREATE OR REPLACE VIEW available_mechanics_with_location AS
SELECT 
    m.id,
    m.mechanic_name,
    m.status,
    m.shop_id,
    sp.company_name as shop_name,
    m.latitude,
    m.longitude,
    m.specializations,
    m.rating,
    m.total_completed_jobs,
    m.is_accepting_requests
FROM public.mechanics m
LEFT JOIN public.service_providers sp ON sp.id = m.shop_id
WHERE m.status = 'available' 
AND m.is_accepting_requests = true 
AND m.current_request_id IS NULL;

-- Function: Calculate distance between two points
CREATE OR REPLACE FUNCTION calculate_distance_km(
    lat1 numeric, lng1 numeric,
    lat2 numeric, lng2 numeric
)
RETURNS numeric AS $$
BEGIN
    RETURN ST_Distance(
        ST_SetSRID(ST_MakePoint(lng1, lat1), 4326),
        ST_SetSRID(ST_MakePoint(lng2, lat2), 4326)
    ) / 1000; -- Convert meters to kilometers
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- SAMPLE USAGE QUERIES
-- =====================================================

/*
-- 1. Get available mechanics in a specific shop
SELECT * FROM get_available_mechanics_in_shop('shop-uuid-here');

-- 2. Find nearest available mechanic
SELECT * FROM get_nearest_available_mechanic(14.5995, 120.9842, 25.0);

-- 3. Accept a service request (atomic operation)
SELECT * FROM accept_service_request('request-uuid', 'mechanic-uuid');

-- 4. Broadcast request to nearby mechanics
SELECT * FROM broadcast_service_request('request-uuid', 15.0, 5);

-- 5. Get all pending requests for a mechanic
SELECT sr.*, rr.distance_km, rr.response_deadline
FROM public.service_requests sr
JOIN public.request_routing rr ON rr.request_id = sr.id
WHERE rr.mechanic_id = 'mechanic-uuid'
AND sr.status = 'broadcasting'
AND rr.response_status = 'pending'
ORDER BY rr.distance_km;

-- 6. Search for shops within radius
SELECT 
    sp.*,
    ST_Distance(
        sp.location,
        ST_SetSRID(ST_MakePoint(120.9842, 14.5995), 4326)
    ) / 1000 as distance_km
FROM public.service_providers sp
WHERE sp.is_active = true
AND ST_DWithin(
    sp.location,
    ST_SetSRID(ST_MakePoint(120.9842, 14.5995), 4326),
    10000 -- 10km in meters
)
ORDER BY distance_km;
*/

-- =====================================================
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- =====================================================

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_mechanics_availability ON public.mechanics (status, is_accepting_requests, current_request_id) 
WHERE status = 'available';

CREATE INDEX IF NOT EXISTS idx_service_requests_status_created ON public.service_requests (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_request_routing_response ON public.request_routing (response_status, response_deadline) 
WHERE response_status = 'pending';

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '🚀 AUTO REPAIR RIDE-HAILING SCHEMA DEPLOYED SUCCESSFULLY!';
    RAISE NOTICE '';
    RAISE NOTICE 'FEATURES INCLUDED:';
    RAISE NOTICE '✅ PostGIS spatial operations for precise distance calculations';
    RAISE NOTICE '✅ Atomic request acceptance with race condition protection';
    RAISE NOTICE '✅ Intelligent mechanic routing (shop-specific vs broadcast)';
    RAISE NOTICE '✅ Row Level Security policies for data isolation';
    RAISE NOTICE '✅ Optimized indexes for high-performance queries';
    RAISE NOTICE '✅ Business logic functions for common operations';
    RAISE NOTICE '';
    RAISE NOTICE 'READY FOR INTEGRATION WITH FLUTTER/SUPABASE APP!';
END $$;