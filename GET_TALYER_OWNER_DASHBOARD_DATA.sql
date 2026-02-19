    -- ========================================
    -- 🏪 TALYER OWNER DASHBOARD - COMPLETE DATA
    -- ========================================
    -- Create SECURITY DEFINER functions to get ALL dashboard data
    -- Bypasses RLS while maintaining security
    -- ========================================

    -- ========================================
    -- FUNCTION 1: Get Dashboard Summary Stats
    -- ========================================

    DROP FUNCTION IF EXISTS get_talyer_owner_dashboard_stats();

    CREATE OR REPLACE FUNCTION get_talyer_owner_dashboard_stats()
    RETURNS TABLE (
    -- Shop Info
    shop_id uuid,
    shop_name text,
    shop_address text,
    shop_phone text,
    shop_status text,
    
    -- Mechanic Stats
    total_mechanics bigint,
    available_mechanics bigint,
    busy_mechanics bigint,
    
    -- Job Stats
    total_jobs bigint,
    active_jobs bigint,
    completed_jobs bigint,
    pending_requests bigint,
    
    -- Earnings Stats
    total_earnings numeric,
    today_earnings numeric,
    this_week_earnings numeric,
    this_month_earnings numeric,
    
    -- Customer Stats
    total_customers bigint,
    active_customers_today bigint,
    
    -- Rating Stats
    average_shop_rating numeric,
    total_shop_reviews integer
    )
    SECURITY DEFINER
    SET search_path = public
    LANGUAGE plpgsql
    AS $$
    DECLARE
    v_shop_id uuid;
    v_user_id uuid;
    BEGIN
    -- Get current user ID (works for both auth.users and user_profiles since they share same ID)
    v_user_id := auth.uid();
    
    -- Get shop_id for current user (check both direct auth.uid() and via user_profiles)
    SELECT s.id INTO v_shop_id
    FROM shops s
    WHERE s.owner_id = v_user_id
        OR s.owner_id IN (SELECT id FROM user_profiles WHERE id = v_user_id);
    
    -- If still not found, try to find by checking user_profiles table
    IF v_shop_id IS NULL THEN
        SELECT s.id INTO v_shop_id
        FROM shops s
        INNER JOIN user_profiles up ON up.id = s.owner_id
        WHERE up.id = v_user_id OR up.email = (SELECT email FROM auth.users WHERE id = v_user_id);
    END IF;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'No shop found for current user. User ID: %, Email: %', 
        v_user_id, 
        (SELECT email FROM auth.users WHERE id = v_user_id);
    END IF;
    
    RETURN QUERY
    SELECT 
        -- Shop Info
        s.id as shop_id,
        s.shop_name::text,
        s.shop_address::text,
        s.shop_phone::text,
        s.current_status::text,
        
        -- Mechanic Stats
        (SELECT COUNT(*) FROM shop_mechanics sm WHERE sm.shop_id = s.id AND sm.is_active = true) as total_mechanics,
        (SELECT COUNT(*) FROM shop_mechanics sm 
        INNER JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
        WHERE sm.shop_id = s.id AND sm.is_active = true AND sm.is_available = true 
        AND mas.current_status = 'available') as available_mechanics,
        (SELECT COUNT(*) FROM shop_mechanics sm 
        INNER JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
        WHERE sm.shop_id = s.id AND sm.is_active = true 
        AND mas.current_status IN ('busy', 'in_service')) as busy_mechanics,
        
        -- Job Stats
        (SELECT COUNT(*) FROM service_requests sr WHERE sr.shop_id = s.id) as total_jobs,
        (SELECT COUNT(*) FROM service_requests sr 
        WHERE sr.shop_id = s.id 
        AND sr.status IN ('accepted', 'assigned', 'in_progress', 'mechanic_assigned')) as active_jobs,
        (SELECT COUNT(*) FROM service_requests sr 
        WHERE sr.shop_id = s.id AND sr.status = 'completed') as completed_jobs,
        (SELECT COUNT(*) FROM service_requests sr 
        WHERE sr.shop_id = s.id AND sr.status = 'pending') as pending_requests,
        
        -- Earnings Stats
        COALESCE((SELECT SUM(mjh.shop_earnings) 
                FROM mechanic_job_history mjh 
                WHERE mjh.shop_id = s.id AND mjh.job_status = 'completed'), 0) as total_earnings,
        COALESCE((SELECT SUM(mjh.shop_earnings) 
                FROM mechanic_job_history mjh 
                WHERE mjh.shop_id = s.id AND mjh.job_status = 'completed'
                    AND DATE(mjh.completed_at) = CURRENT_DATE), 0) as today_earnings,
        COALESCE((SELECT SUM(mjh.shop_earnings) 
                FROM mechanic_job_history mjh 
                WHERE mjh.shop_id = s.id AND mjh.job_status = 'completed'
                    AND mjh.completed_at >= DATE_TRUNC('week', CURRENT_DATE)), 0) as this_week_earnings,
        COALESCE((SELECT SUM(mjh.shop_earnings) 
                FROM mechanic_job_history mjh 
                WHERE mjh.shop_id = s.id AND mjh.job_status = 'completed'
                    AND mjh.completed_at >= DATE_TRUNC('month', CURRENT_DATE)), 0) as this_month_earnings,
        
        -- Customer Stats
        (SELECT COUNT(DISTINCT sr.customer_id) 
        FROM service_requests sr 
        WHERE sr.shop_id = s.id) as total_customers,
        (SELECT COUNT(DISTINCT sr.customer_id) 
        FROM service_requests sr 
        WHERE sr.shop_id = s.id 
        AND DATE(sr.created_at) = CURRENT_DATE) as active_customers_today,
        
        -- Rating Stats
        COALESCE(s.rating, 0) as average_shop_rating,
        COALESCE(s.total_reviews, 0) as total_shop_reviews
        
    FROM shops s
    WHERE s.id = v_shop_id;
    END;
    $$;

    -- ========================================
    -- FUNCTION 2: Get Recent Service Requests
    -- ========================================

    DROP FUNCTION IF EXISTS get_talyer_owner_recent_requests(integer);

    CREATE OR REPLACE FUNCTION get_talyer_owner_recent_requests(limit_count integer DEFAULT 10)
    RETURNS TABLE (
    request_id uuid,
    customer_id uuid,
    customer_name text,
    customer_phone text,
    customer_email text,
    vehicle_info text,
    service_title text,
    service_description text,
    request_status text,
    pickup_address text,
    pickup_latitude numeric,
    pickup_longitude numeric,
    estimated_price numeric,
    assigned_mechanic_id uuid,
    assigned_mechanic_name text,
    created_at timestamp with time zone,
    accepted_at timestamp with time zone,
    completed_at timestamp with time zone,
    distance_km numeric
    )
    SECURITY DEFINER
    SET search_path = public
    LANGUAGE plpgsql
    AS $$
    DECLARE
    v_shop_id uuid;
    v_user_id uuid;
    BEGIN
    v_user_id := auth.uid();
    
    SELECT s.id INTO v_shop_id
    FROM shops s
    WHERE s.owner_id = v_user_id
        OR s.owner_id IN (SELECT id FROM user_profiles WHERE id = v_user_id);
    
    IF v_shop_id IS NULL THEN
        SELECT s.id INTO v_shop_id
        FROM shops s
        INNER JOIN user_profiles up ON up.id = s.owner_id
        WHERE up.id = v_user_id OR up.email = (SELECT email FROM auth.users WHERE id = v_user_id);
    END IF;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'No shop found for user';
    END IF;
    
    RETURN QUERY
    SELECT 
        sr.id as request_id,
        sr.customer_id,
        (up.first_name || ' ' || up.last_name)::text as customer_name,
        up.phone_number::text as customer_phone,
        up.email::text as customer_email,
        sr.vehicle_info::text,
        sr.title::text as service_title,
        sr.description::text as service_description,
        sr.status::text as request_status,
        sr.pickup_address::text,
        sr.pickup_latitude,
        sr.pickup_longitude,
        sr.estimated_price,
        sr.assigned_mechanic_id,
        CASE 
        WHEN sr.assigned_mechanic_id IS NOT NULL 
        THEN (m.first_name || ' ' || m.last_name)::text
        ELSE NULL
        END as assigned_mechanic_name,
        sr.created_at,
        sr.accepted_at,
        sr.completed_at,
        sr.distance_km
    FROM service_requests sr
    INNER JOIN user_profiles up ON up.id = sr.customer_id
    LEFT JOIN user_profiles m ON m.id = sr.assigned_mechanic_id
    WHERE sr.shop_id = v_shop_id
    ORDER BY sr.created_at DESC
    LIMIT limit_count;
    END;
    $$;

    -- ========================================
    -- FUNCTION 3: Get Mechanic Job Stats (for dashboard)
    -- ========================================

    DROP FUNCTION IF EXISTS get_talyer_owner_mechanic_stats();

    CREATE OR REPLACE FUNCTION get_talyer_owner_mechanic_stats()
    RETURNS TABLE (
    mechanic_id uuid,
    mechanic_name text,
    mechanic_email text,
    mechanic_phone text,
    profile_image_url text,
    rating numeric,
    total_reviews integer,
    
    -- Job Stats
    total_jobs bigint,
    completed_jobs bigint,
    active_jobs bigint,
    
    -- Earnings Stats
    total_earnings numeric,
    today_earnings numeric,
    this_week_earnings numeric,
    this_month_earnings numeric,
    
    -- Availability
    current_status text,
    is_available boolean,
    is_active boolean
    )
    SECURITY DEFINER
    SET search_path = public
    LANGUAGE plpgsql
    AS $$
    DECLARE
    v_shop_id uuid;
    v_user_id uuid;
    BEGIN
    v_user_id := auth.uid();
    
    SELECT s.id INTO v_shop_id
    FROM shops s
    WHERE s.owner_id = v_user_id
        OR s.owner_id IN (SELECT id FROM user_profiles WHERE id = v_user_id);
    
    IF v_shop_id IS NULL THEN
        SELECT s.id INTO v_shop_id
        FROM shops s
        INNER JOIN user_profiles up ON up.id = s.owner_id
        WHERE up.id = v_user_id OR up.email = (SELECT email FROM auth.users WHERE id = v_user_id);
    END IF;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'No shop found for user';
    END IF;
    
    RETURN QUERY
    SELECT 
        up.id as mechanic_id,
        (up.first_name || ' ' || up.last_name)::text as mechanic_name,
        up.email::text as mechanic_email,
        up.phone_number::text as mechanic_phone,
        up.profile_image_url::text,
        COALESCE(up.rating, 0) as rating,
        COALESCE(up.total_reviews, 0) as total_reviews,
        
        -- Job Stats
        (SELECT COUNT(*) FROM mechanic_job_history mjh 
        WHERE mjh.mechanic_id = up.id AND mjh.shop_id = v_shop_id) as total_jobs,
        (SELECT COUNT(*) FROM mechanic_job_history mjh 
        WHERE mjh.mechanic_id = up.id AND mjh.shop_id = v_shop_id 
        AND mjh.job_status = 'completed') as completed_jobs,
        (SELECT COUNT(*) FROM service_requests sr 
        WHERE sr.assigned_mechanic_id = up.id AND sr.shop_id = v_shop_id
        AND sr.status IN ('accepted', 'assigned', 'in_progress', 'mechanic_assigned')) as active_jobs,
        
        -- Earnings Stats
        COALESCE((SELECT SUM(mjh.mechanic_earnings) 
                FROM mechanic_job_history mjh 
                WHERE mjh.mechanic_id = up.id AND mjh.shop_id = v_shop_id 
                    AND mjh.job_status = 'completed'), 0) as total_earnings,
        COALESCE((SELECT SUM(mjh.mechanic_earnings) 
                FROM mechanic_job_history mjh 
                WHERE mjh.mechanic_id = up.id AND mjh.shop_id = v_shop_id 
                    AND mjh.job_status = 'completed'
                    AND DATE(mjh.completed_at) = CURRENT_DATE), 0) as today_earnings,
        COALESCE((SELECT SUM(mjh.mechanic_earnings) 
                FROM mechanic_job_history mjh 
                WHERE mjh.mechanic_id = up.id AND mjh.shop_id = v_shop_id 
                    AND mjh.job_status = 'completed'
                    AND mjh.completed_at >= DATE_TRUNC('week', CURRENT_DATE)), 0) as this_week_earnings,
        COALESCE((SELECT SUM(mjh.mechanic_earnings) 
                FROM mechanic_job_history mjh 
                WHERE mjh.mechanic_id = up.id AND mjh.shop_id = v_shop_id 
                    AND mjh.job_status = 'completed'
                    AND mjh.completed_at >= DATE_TRUNC('month', CURRENT_DATE)), 0) as this_month_earnings,
        
        -- Availability
        COALESCE(mas.current_status::text, 'offline') as current_status,
        sm.is_available,
        sm.is_active
        
    FROM shop_mechanics sm
    INNER JOIN user_profiles up ON up.id = sm.mechanic_id
    LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
    WHERE sm.shop_id = v_shop_id
    ORDER BY up.first_name, up.last_name;
    END;
    $$;

    -- ========================================
    -- FUNCTION 4: Get Customer List with Stats
    -- ========================================

    DROP FUNCTION IF EXISTS get_talyer_owner_customers();

    CREATE OR REPLACE FUNCTION get_talyer_owner_customers()
    RETURNS TABLE (
    customer_id uuid,
    customer_name text,
    customer_email text,
    customer_phone text,
    profile_image_url text,
    
    -- Stats
    total_requests bigint,
    completed_requests bigint,
    total_spent numeric,
    last_service_date timestamp with time zone,
    
    -- Latest Request
    latest_request_id uuid,
    latest_request_status text
    )
    SECURITY DEFINER
    SET search_path = public
    LANGUAGE plpgsql
    AS $$
    DECLARE
    v_shop_id uuid;
    v_user_id uuid;
    BEGIN
    v_user_id := auth.uid();
    
    SELECT s.id INTO v_shop_id
    FROM shops s
    WHERE s.owner_id = v_user_id
        OR s.owner_id IN (SELECT id FROM user_profiles WHERE id = v_user_id);
    
    IF v_shop_id IS NULL THEN
        SELECT s.id INTO v_shop_id
        FROM shops s
        INNER JOIN user_profiles up ON up.id = s.owner_id
        WHERE up.id = v_user_id OR up.email = (SELECT email FROM auth.users WHERE id = v_user_id);
    END IF;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'No shop found for user';
    END IF;
    
    RETURN QUERY
    SELECT 
        up.id as customer_id,
        (up.first_name || ' ' || up.last_name)::text as customer_name,
        up.email::text as customer_email,
        up.phone_number::text as customer_phone,
        up.profile_image_url::text,
        
        -- Stats
        COUNT(sr.id) as total_requests,
        COUNT(CASE WHEN sr.status = 'completed' THEN 1 END) as completed_requests,
        COALESCE(SUM(CASE WHEN sr.status = 'completed' THEN sr.final_price END), 0) as total_spent,
        MAX(sr.completed_at) as last_service_date,
        
        -- Latest Request
        (SELECT id FROM service_requests 
        WHERE customer_id = up.id AND shop_id = v_shop_id 
        ORDER BY created_at DESC LIMIT 1) as latest_request_id,
        (SELECT status::text FROM service_requests 
        WHERE customer_id = up.id AND shop_id = v_shop_id 
        ORDER BY created_at DESC LIMIT 1) as latest_request_status
        
    FROM user_profiles up
    INNER JOIN service_requests sr ON sr.customer_id = up.id
    WHERE sr.shop_id = v_shop_id
    GROUP BY up.id, up.first_name, up.last_name, up.email, up.phone_number, up.profile_image_url
    ORDER BY last_service_date DESC NULLS LAST;
    END;
    $$;

    -- ========================================
    -- FUNCTION 5: Get Earnings Breakdown
    -- ========================================

    DROP FUNCTION IF EXISTS get_talyer_owner_earnings_breakdown();

    CREATE OR REPLACE FUNCTION get_talyer_owner_earnings_breakdown()
    RETURNS TABLE (
    period text,
    total_revenue numeric,
    shop_earnings numeric,
    mechanic_earnings numeric,
    platform_fees numeric,
    completed_jobs bigint
    )
    SECURITY DEFINER
    SET search_path = public
    LANGUAGE plpgsql
    AS $$
    DECLARE
    v_shop_id uuid;
    v_user_id uuid;
    BEGIN
    v_user_id := auth.uid();
    
    SELECT s.id INTO v_shop_id
    FROM shops s
    WHERE s.owner_id = v_user_id
        OR s.owner_id IN (SELECT id FROM user_profiles WHERE id = v_user_id);
    
    IF v_shop_id IS NULL THEN
        SELECT s.id INTO v_shop_id
        FROM shops s
        INNER JOIN user_profiles up ON up.id = s.owner_id
        WHERE up.id = v_user_id OR up.email = (SELECT email FROM auth.users WHERE id = v_user_id);
    END IF;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'No shop found for user';
    END IF;
    
    RETURN QUERY
    SELECT 
        'Today' as period,
        COALESCE(SUM(total_amount), 0) as total_revenue,
        COALESCE(SUM(shop_earnings), 0) as shop_earnings,
        COALESCE(SUM(mechanic_earnings), 0) as mechanic_earnings,
        COALESCE(SUM(platform_fee), 0) as platform_fees,
        COUNT(*) as completed_jobs
    FROM mechanic_job_history
    WHERE shop_id = v_shop_id 
        AND job_status = 'completed'
        AND DATE(completed_at) = CURRENT_DATE
    
    UNION ALL
    
    SELECT 
        'This Week' as period,
        COALESCE(SUM(total_amount), 0),
        COALESCE(SUM(shop_earnings), 0),
        COALESCE(SUM(mechanic_earnings), 0),
        COALESCE(SUM(platform_fee), 0),
        COUNT(*)
    FROM mechanic_job_history
    WHERE shop_id = v_shop_id 
        AND job_status = 'completed'
        AND completed_at >= DATE_TRUNC('week', CURRENT_DATE)
    
    UNION ALL
    
    SELECT 
        'This Month' as period,
        COALESCE(SUM(total_amount), 0),
        COALESCE(SUM(shop_earnings), 0),
        COALESCE(SUM(mechanic_earnings), 0),
        COALESCE(SUM(platform_fee), 0),
        COUNT(*)
    FROM mechanic_job_history
    WHERE shop_id = v_shop_id 
        AND job_status = 'completed'
        AND completed_at >= DATE_TRUNC('month', CURRENT_DATE)
    
    UNION ALL
    
    SELECT 
        'All Time' as period,
        COALESCE(SUM(total_amount), 0),
        COALESCE(SUM(shop_earnings), 0),
        COALESCE(SUM(mechanic_earnings), 0),
        COALESCE(SUM(platform_fee), 0),
        COUNT(*)
    FROM mechanic_job_history
    WHERE shop_id = v_shop_id 
        AND job_status = 'completed';
    END;
    $$;

    -- ========================================
    -- TEST FUNCTIONS
    -- ========================================

    SELECT '=== 🧪 TEST 1: Dashboard Stats ===' as section;
    SELECT * FROM get_talyer_owner_dashboard_stats();

    SELECT '=== 🧪 TEST 2: Recent Requests ===' as section;
    SELECT * FROM get_talyer_owner_recent_requests(5);

    SELECT '=== 🧪 TEST 3: Mechanic Stats ===' as section;
    SELECT * FROM get_talyer_owner_mechanic_stats();

    SELECT '=== 🧪 TEST 4: Customer List ===' as section;
    SELECT * FROM get_talyer_owner_customers();

    SELECT '=== 🧪 TEST 5: Earnings Breakdown ===' as section;
    SELECT * FROM get_talyer_owner_earnings_breakdown();

    -- ========================================
    -- SUCCESS MESSAGE
    -- ========================================
    DO $$
    BEGIN
        RAISE NOTICE '========================================';
        RAISE NOTICE '✅ TALYER OWNER DASHBOARD FUNCTIONS CREATED!';
        RAISE NOTICE '========================================';
        RAISE NOTICE '';
        RAISE NOTICE 'Created 5 comprehensive dashboard functions:';
        RAISE NOTICE '  1. get_talyer_owner_dashboard_stats()';
        RAISE NOTICE '  2. get_talyer_owner_recent_requests(limit)';
        RAISE NOTICE '  3. get_talyer_owner_mechanic_stats()';
        RAISE NOTICE '  4. get_talyer_owner_customers()';
        RAISE NOTICE '  5. get_talyer_owner_earnings_breakdown()';
        RAISE NOTICE '';
        RAISE NOTICE 'These functions:';
        RAISE NOTICE '  ✅ Bypass RLS (no infinite recursion!)';
        RAISE NOTICE '  ✅ Secure (only show data for owner''s shop)';
        RAISE NOTICE '  ✅ Complete (all dashboard data included)';
        RAISE NOTICE '  ✅ Computed (earnings, stats, counts calculated)';
        RAISE NOTICE '  ✅ Optimized (efficient queries with proper JOINs)';
        RAISE NOTICE '';
        RAISE NOTICE 'Usage in Flutter:';
        RAISE NOTICE '  .rpc(''get_talyer_owner_dashboard_stats'')';
        RAISE NOTICE '  .rpc(''get_talyer_owner_recent_requests'', {''limit_count'': 10})';
        RAISE NOTICE '  .rpc(''get_talyer_owner_mechanic_stats'')';
        RAISE NOTICE '  .rpc(''get_talyer_owner_customers'')';
        RAISE NOTICE '  .rpc(''get_talyer_owner_earnings_breakdown'')';
        RAISE NOTICE '========================================';
    END $$;
