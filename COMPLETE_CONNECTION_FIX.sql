-- =====================================================
-- COMPLETE MECHANIC-CUSTOMER CONNECTION FIX
-- =====================================================
-- Ensures proper connections:
-- 1. Mechanics connected to shops that added them
-- 2. Customers connected to mechanics who accepted their requests
-- 3. Auto-triggers for future connections
-- =====================================================

BEGIN;

-- =====================================================
-- PART 1: FIX MECHANIC-SHOP CONNECTIONS
-- =====================================================

-- Ensure all mechanics who were added via invitations have proper shop connections
DO $$
DECLARE
    v_invitation_record RECORD;
    v_shop_mechanic_exists boolean;
BEGIN
    RAISE NOTICE '🔧 FIXING MECHANIC-SHOP CONNECTIONS...';
    
    -- Loop through all accepted mechanic invitations that don't have shop_mechanic entries
    FOR v_invitation_record IN
        SELECT DISTINCT
            mi.shop_id,
            mi.mechanic_user_id as mechanic_id,
            mi.shop_owner_id,
            s.shop_name,
            up.first_name,
            up.last_name,
            up.email
        FROM mechanic_invitations mi
        JOIN shops s ON s.id = mi.shop_id
        JOIN user_profiles up ON up.id = mi.mechanic_user_id
        WHERE mi.status = 'accepted' 
        AND mi.mechanic_user_id IS NOT NULL
    LOOP
        -- Check if shop_mechanic entry exists
        SELECT EXISTS(
            SELECT 1 FROM shop_mechanics 
            WHERE shop_id = v_invitation_record.shop_id 
            AND mechanic_id = v_invitation_record.mechanic_id
        ) INTO v_shop_mechanic_exists;
        
        IF NOT v_shop_mechanic_exists THEN
            -- Create the shop_mechanic connection
            INSERT INTO shop_mechanics (
                shop_id,
                mechanic_id,
                role,
                is_active,
                is_available,
                joined_at,
                created_at,
                updated_at
            ) VALUES (
                v_invitation_record.shop_id,
                v_invitation_record.mechanic_id,
                'mechanic',
                true,
                true,
                NOW(),
                NOW(),
                NOW()
            );
            
            RAISE NOTICE '✅ Connected mechanic % % to shop %', 
                v_invitation_record.first_name, 
                v_invitation_record.last_name,
                v_invitation_record.shop_name;
        END IF;
    END LOOP;
END $$;

-- Update user_profiles.shop_id for mechanics who should be connected to shops
UPDATE user_profiles up
SET shop_id = sm.shop_id,
    updated_at = NOW()
FROM shop_mechanics sm
WHERE sm.mechanic_id = up.id 
AND up.user_type = 'mechanic'
AND (up.shop_id IS NULL OR up.shop_id != sm.shop_id)
AND sm.is_active = true;

-- Ensure service_providers have proper talyer_owner_id connections
UPDATE service_providers sp
SET talyer_owner_id = s.owner_id,
    updated_at = NOW()
FROM user_profiles up
JOIN shop_mechanics sm ON sm.mechanic_id = up.id
JOIN shops s ON s.id = sm.shop_id
WHERE sp.user_id = up.id
AND up.user_type = 'mechanic'
AND (sp.talyer_owner_id IS NULL OR sp.talyer_owner_id != s.owner_id)
AND sm.is_active = true;

-- =====================================================
-- PART 2: FIX CUSTOMER-MECHANIC CONNECTIONS
-- =====================================================

-- Ensure talyer_customer_connections exist for all service requests with assigned mechanics
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
    sr.id as service_request_id,
    sr.customer_id,
    s.owner_id as talyer_owner_id,
    sp.id as provider_id,
    CASE 
        WHEN sr.status IN ('completed', 'cancelled') THEN 'completed'
        WHEN sr.status IN ('assigned', 'in_progress', 'inspection_completed', 'invoice_sent', 'invoice_paid') THEN 'connected'
        ELSE 'pending'
    END as status,
    'service_request' as connection_type,
    sr.created_at,
    sr.assigned_at,
    GREATEST(sr.updated_at, NOW()) as last_activity
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

-- Update existing connections with proper details
UPDATE talyer_customer_connections 
SET 
    customer_details = (
        SELECT jsonb_build_object(
            'customer_id', c.id,
            'name', c.first_name || ' ' || c.last_name,
            'email', c.email,
            'phone', c.phone_number
        )
        FROM service_requests sr
        JOIN user_profiles c ON c.id = sr.customer_id
        WHERE sr.id = talyer_customer_connections.service_request_id
    ),
    talyer_details = (
        SELECT jsonb_build_object(
            'talyer_owner_id', talyer_owner.id,
            'name', talyer_owner.first_name || ' ' || talyer_owner.last_name,
            'email', talyer_owner.email,
            'shop_id', s.id,
            'shop_name', s.shop_name
        )
        FROM user_profiles talyer_owner
        JOIN shops s ON s.owner_id = talyer_owner.id
        WHERE talyer_owner.id = talyer_customer_connections.talyer_owner_id
    ),
    last_activity = NOW()
WHERE (talyer_customer_connections.customer_details IS NULL OR talyer_customer_connections.talyer_details IS NULL);

-- =====================================================
-- PART 3: VALIDATION AND CLEANUP
-- =====================================================

-- Remove orphaned shop_mechanics entries (mechanics that don't exist)
DELETE FROM shop_mechanics sm
WHERE NOT EXISTS (
    SELECT 1 FROM user_profiles up 
    WHERE up.id = sm.mechanic_id 
    AND up.user_type = 'mechanic'
);

-- Remove orphaned shop_mechanics entries (shops that don't exist)
DELETE FROM shop_mechanics sm
WHERE NOT EXISTS (
    SELECT 1 FROM shops s 
    WHERE s.id = sm.shop_id 
    AND s.is_active = true
);

-- Fix any service_providers without proper shop connections
UPDATE service_providers sp
SET shop_id = sm.shop_id,
    updated_at = NOW()
FROM user_profiles up
JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
WHERE sp.user_id = up.id
AND up.user_type = 'mechanic'
AND (sp.shop_id IS NULL OR sp.shop_id != sm.shop_id);

-- Update mechanic_availability_status with proper shop connections
INSERT INTO mechanic_availability_status (
    mechanic_id,
    shop_id,
    current_status,
    is_accepting_requests,
    created_at,
    updated_at
)
SELECT 
    sm.mechanic_id,
    sm.shop_id,
    'available',
    sm.is_available,
    NOW(),
    NOW()
FROM shop_mechanics sm
JOIN user_profiles up ON up.id = sm.mechanic_id
WHERE sm.is_active = true
AND up.user_type = 'mechanic'
ON CONFLICT (mechanic_id) DO UPDATE SET
    shop_id = EXCLUDED.shop_id,
    updated_at = NOW();

-- =====================================================
-- PART 4: CREATE VALIDATION VIEWS
-- =====================================================

-- Create view for mechanic-shop connections
CREATE OR REPLACE VIEW v_mechanic_shop_connections AS
SELECT 
    up.id as mechanic_id,
    up.first_name || ' ' || up.last_name as mechanic_name,
    up.email as mechanic_email,
    s.id as shop_id,
    s.shop_name,
    shop_owner.first_name || ' ' || shop_owner.last_name as shop_owner_name,
    shop_owner.email as shop_owner_email,
    sm.role as mechanic_role,
    sm.is_active,
    sm.is_available,
    sm.joined_at,
    sp.id as service_provider_id,
    sp.talyer_owner_id
FROM user_profiles up
JOIN shop_mechanics sm ON sm.mechanic_id = up.id
JOIN shops s ON s.id = sm.shop_id
JOIN user_profiles shop_owner ON shop_owner.id = s.owner_id
LEFT JOIN service_providers sp ON sp.user_id = up.id
WHERE up.user_type = 'mechanic' AND sm.is_active = true;

-- Create view for customer-mechanic connections
CREATE OR REPLACE VIEW v_customer_mechanic_connections AS
SELECT 
    sr.id as request_id,
    sr.title as service_title,
    customer.first_name || ' ' || customer.last_name as customer_name,
    customer.email as customer_email,
    mechanic.first_name || ' ' || mechanic.last_name as mechanic_name,
    mechanic.email as mechanic_email,
    owner.first_name || ' ' || owner.last_name as shop_owner_name,
    s.shop_name,
    sr.status as request_status,
    sr.created_at as request_created,
    sr.assigned_at,
    tcc.status as connection_status,
    tcc.connected_at
FROM service_requests sr
JOIN user_profiles customer ON customer.id = sr.customer_id
LEFT JOIN user_profiles mechanic ON mechanic.id = sr.assigned_mechanic_id
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = mechanic.id AND sm.is_active = true
LEFT JOIN shops s ON s.id = sm.shop_id
LEFT JOIN user_profiles owner ON owner.id = s.owner_id
LEFT JOIN talyer_customer_connections tcc ON tcc.service_request_id = sr.id
ORDER BY sr.created_at DESC;

-- =====================================================
-- PART 5: CREATE TRIGGERS FOR AUTO-MAINTENANCE
-- =====================================================

-- Function to ensure mechanic invitation creates shop_mechanic entry
CREATE OR REPLACE FUNCTION ensure_mechanic_shop_connection()
RETURNS TRIGGER AS $$
BEGIN
    -- When a mechanic invitation is accepted, ensure shop_mechanic entry exists
    IF NEW.status = 'accepted' AND NEW.mechanic_user_id IS NOT NULL THEN
        INSERT INTO shop_mechanics (
            shop_id,
            mechanic_id,
            role,
            is_active,
            is_available,
            joined_at,
            created_at,
            updated_at
        ) VALUES (
            NEW.shop_id,
            NEW.mechanic_user_id,
            'mechanic',
            true,
            true,
            NEW.accepted_at,
            NOW(),
            NOW()
        )
        ON CONFLICT (shop_id, mechanic_id) DO UPDATE SET
            is_active = true,
            updated_at = NOW();
            
        -- Update user_profiles with shop connection
        UPDATE user_profiles 
        SET shop_id = NEW.shop_id,
            updated_at = NOW()
        WHERE id = NEW.mechanic_user_id;
        
        -- Update service_providers with talyer_owner connection
        UPDATE service_providers sp
        SET talyer_owner_id = s.owner_id,
            shop_id = NEW.shop_id,
            updated_at = NOW()
        FROM shops s
        WHERE s.id = NEW.shop_id
        AND sp.user_id = NEW.mechanic_user_id;
        
        RAISE NOTICE '✅ Auto-connected mechanic % to shop %', NEW.mechanic_user_id, NEW.shop_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create talyer_customer_connection when mechanic is assigned
CREATE OR REPLACE FUNCTION ensure_customer_mechanic_connection()
RETURNS TRIGGER AS $$
DECLARE
    v_talyer_owner_id uuid;
    v_service_provider_id uuid;
BEGIN
    -- When a mechanic is assigned to a service request
    IF NEW.assigned_mechanic_id IS NOT NULL AND (OLD.assigned_mechanic_id IS NULL OR OLD.assigned_mechanic_id != NEW.assigned_mechanic_id) THEN
        
        -- Get talyer owner and service provider info
        SELECT s.owner_id, sp.id
        INTO v_talyer_owner_id, v_service_provider_id
        FROM user_profiles up
        LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
        LEFT JOIN shops s ON s.id = sm.shop_id
        LEFT JOIN service_providers sp ON sp.user_id = up.id
        WHERE up.id = NEW.assigned_mechanic_id
        LIMIT 1;
        
        -- Create or update talyer_customer_connection
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
        ) VALUES (
            NEW.id,
            NEW.customer_id,
            v_talyer_owner_id,
            v_service_provider_id,
            'connected',
            'service_request',
            NOW(),
            NOW(),
            NOW()
        )
        ON CONFLICT (service_request_id) DO UPDATE SET
            talyer_owner_id = v_talyer_owner_id,
            provider_id = v_service_provider_id,
            status = 'connected',
            connected_at = NOW(),
            last_activity = NOW();
            
        RAISE NOTICE '✅ Auto-connected customer % to mechanic % via talyer %', NEW.customer_id, NEW.assigned_mechanic_id, v_talyer_owner_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
DROP TRIGGER IF EXISTS trg_mechanic_invitation_accepted ON mechanic_invitations;
CREATE TRIGGER trg_mechanic_invitation_accepted
    AFTER UPDATE ON mechanic_invitations
    FOR EACH ROW
    WHEN (OLD.status != 'accepted' AND NEW.status = 'accepted')
    EXECUTE FUNCTION ensure_mechanic_shop_connection();

DROP TRIGGER IF EXISTS trg_service_request_mechanic_assigned ON service_requests;
CREATE TRIGGER trg_service_request_mechanic_assigned
    AFTER UPDATE ON service_requests
    FOR EACH ROW
    WHEN (NEW.assigned_mechanic_id IS NOT NULL)
    EXECUTE FUNCTION ensure_customer_mechanic_connection();

-- =====================================================
-- PART 6: CREATE VALIDATION FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION validate_connection_integrity()
RETURNS TABLE (
    check_type text,
    status text,
    count_found integer,
    details text
) AS $$
BEGIN
    -- Check 1: Mechanics without shop connections
    RETURN QUERY
    SELECT 
        'Orphaned Mechanics'::text,
        CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END::text,
        COUNT(*)::integer,
        'Mechanics without shop_mechanics entries'::text
    FROM user_profiles up
    LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
    WHERE up.user_type = 'mechanic' AND sm.id IS NULL;
    
    -- Check 2: Service requests without customer connections
    RETURN QUERY
    SELECT 
        'Missing Customer Connections'::text,
        CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END::text,
        COUNT(*)::integer,
        'Service requests with assigned mechanics but no talyer_customer_connections'::text
    FROM service_requests sr
    WHERE sr.assigned_mechanic_id IS NOT NULL
    AND NOT EXISTS (
        SELECT 1 FROM talyer_customer_connections tcc 
        WHERE tcc.service_request_id = sr.id
    );
END;
$$ LANGUAGE plpgsql;

-- Create unique constraints
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'shop_mechanics_shop_id_mechanic_id_key'
    ) THEN
        ALTER TABLE shop_mechanics 
        ADD CONSTRAINT shop_mechanics_shop_id_mechanic_id_key 
        UNIQUE (shop_id, mechanic_id);
    END IF;
END $$;

-- Report on connections created
DO $$
DECLARE
    v_shop_connections_count integer;
    v_customer_connections_count integer;
    v_orphaned_mechanics integer;
    v_mechanic_history_count integer;
    v_customer_history_count integer;
BEGIN
    -- Count shop connections
    SELECT COUNT(*) INTO v_shop_connections_count
    FROM shop_mechanics sm
    JOIN user_profiles up ON up.id = sm.mechanic_id
    WHERE sm.is_active = true AND up.user_type = 'mechanic';
    
    -- Count customer connections
    SELECT COUNT(*) INTO v_customer_connections_count
    FROM talyer_customer_connections
    WHERE status IN ('connected', 'completed');
    
    -- Count mechanics without shops
    SELECT COUNT(*) INTO v_orphaned_mechanics
    FROM user_profiles up
    LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
    WHERE up.user_type = 'mechanic' AND sm.id IS NULL;
    
    -- Count job history entries (only if tables exist)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'mechanic_job_history') THEN
        SELECT COUNT(*) INTO v_mechanic_history_count FROM mechanic_job_history;
    ELSE
        v_mechanic_history_count := 0;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customer_job_history') THEN
        SELECT COUNT(*) INTO v_customer_history_count FROM customer_job_history;
    ELSE
        v_customer_history_count := 0;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🎯 CONNECTION REPAIR SUMMARY:';
    RAISE NOTICE '✅ Shop-Mechanic Connections: %', v_shop_connections_count;
    RAISE NOTICE '✅ Customer-Mechanic Connections: %', v_customer_connections_count;
    RAISE NOTICE '📚 Mechanic Job History Entries: %', v_mechanic_history_count;
    RAISE NOTICE '📚 Customer Job History Entries: %', v_customer_history_count;
    RAISE NOTICE '⚠️ Orphaned Mechanics: %', v_orphaned_mechanics;
    RAISE NOTICE '';
END $$;

-- =====================================================
-- PART 7: JOB HISTORY SYSTEM
-- =====================================================

-- Create job history tables if they don't exist
CREATE TABLE IF NOT EXISTS mechanic_job_history (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    mechanic_id uuid NOT NULL REFERENCES user_profiles(id),
    service_request_id uuid NOT NULL REFERENCES service_requests(id),
    customer_id uuid NOT NULL REFERENCES user_profiles(id),
    shop_id uuid REFERENCES shops(id),
    job_title text NOT NULL,
    job_description text,
    job_status text NOT NULL,
    completed_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    total_amount decimal(10,2),
    rating decimal(2,1),
    review_text text,
    job_duration_minutes integer,
    created_at timestamp with time zone DEFAULT NOW(),
    updated_at timestamp with time zone DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS customer_job_history (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    customer_id uuid NOT NULL REFERENCES user_profiles(id),
    service_request_id uuid NOT NULL REFERENCES service_requests(id),
    mechanic_id uuid REFERENCES user_profiles(id),
    shop_id uuid REFERENCES shops(id),
    job_title text NOT NULL,
    job_description text,
    job_status text NOT NULL,
    completed_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    total_amount decimal(10,2),
    rating decimal(2,1),
    review_text text,
    mechanic_name text,
    shop_name text,
    created_at timestamp with time zone DEFAULT NOW(),
    updated_at timestamp with time zone DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_mechanic_job_history_mechanic_id ON mechanic_job_history(mechanic_id);
CREATE INDEX IF NOT EXISTS idx_mechanic_job_history_status ON mechanic_job_history(job_status);
CREATE INDEX IF NOT EXISTS idx_customer_job_history_customer_id ON customer_job_history(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_job_history_status ON customer_job_history(job_status);

-- Function to add job to history when completed or cancelled
CREATE OR REPLACE FUNCTION add_job_to_history()
RETURNS TRIGGER AS $$
DECLARE
    v_mechanic_name text;
    v_shop_name text;
    v_shop_id uuid;
    v_total_amount decimal(10,2);
    v_rating decimal(2,1);
    v_review_text text;
    v_job_duration_minutes integer;
BEGIN
    -- Only process when job is completed or cancelled
    IF NEW.status IN ('completed', 'cancelled') AND OLD.status NOT IN ('completed', 'cancelled') THEN
        
        -- Get mechanic and shop details
        SELECT 
            up.first_name || ' ' || up.last_name,
            s.shop_name,
            s.id
        INTO v_mechanic_name, v_shop_name, v_shop_id
        FROM user_profiles up
        LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
        LEFT JOIN shops s ON s.id = sm.shop_id
        WHERE up.id = NEW.assigned_mechanic_id;
        
        -- Get payment and review details if available
        SELECT 
            p.amount,
            r.rating,
            r.comment
        INTO v_total_amount, v_rating, v_review_text
        FROM service_requests sr
        LEFT JOIN payments p ON p.request_id = sr.id
        LEFT JOIN reviews r ON r.request_id = sr.id
        WHERE sr.id = NEW.id;
        
        -- Calculate job duration
        IF NEW.status = 'completed' AND NEW.assigned_at IS NOT NULL THEN
            v_job_duration_minutes := EXTRACT(EPOCH FROM (NOW() - NEW.assigned_at)) / 60;
        END IF;
        
        -- Add to mechanic job history
        IF NEW.assigned_mechanic_id IS NOT NULL THEN
            INSERT INTO mechanic_job_history (
                mechanic_id,
                service_request_id,
                customer_id,
                shop_id,
                job_title,
                job_description,
                job_status,
                completed_at,
                cancelled_at,
                total_amount,
                rating,
                review_text,
                job_duration_minutes,
                created_at,
                updated_at
            ) VALUES (
                NEW.assigned_mechanic_id,
                NEW.id,
                NEW.customer_id,
                v_shop_id,
                NEW.title,
                NEW.description,
                NEW.status,
                CASE WHEN NEW.status = 'completed' THEN NOW() ELSE NULL END,
                CASE WHEN NEW.status = 'cancelled' THEN NOW() ELSE NULL END,
                v_total_amount,
                v_rating,
                v_review_text,
                v_job_duration_minutes,
                NOW(),
                NOW()
            )
            ON CONFLICT (service_request_id, mechanic_id) DO UPDATE SET
                job_status = NEW.status,
                completed_at = CASE WHEN NEW.status = 'completed' THEN NOW() ELSE mechanic_job_history.completed_at END,
                cancelled_at = CASE WHEN NEW.status = 'cancelled' THEN NOW() ELSE mechanic_job_history.cancelled_at END,
                total_amount = v_total_amount,
                rating = v_rating,
                review_text = v_review_text,
                updated_at = NOW();
        END IF;
        
        -- Add to customer job history
        INSERT INTO customer_job_history (
            customer_id,
            service_request_id,
            mechanic_id,
            shop_id,
            job_title,
            job_description,
            job_status,
            completed_at,
            cancelled_at,
            total_amount,
            rating,
            review_text,
            mechanic_name,
            shop_name,
            created_at,
            updated_at
        ) VALUES (
            NEW.customer_id,
            NEW.id,
            NEW.assigned_mechanic_id,
            v_shop_id,
            NEW.title,
            NEW.description,
            NEW.status,
            CASE WHEN NEW.status = 'completed' THEN NOW() ELSE NULL END,
            CASE WHEN NEW.status = 'cancelled' THEN NOW() ELSE NULL END,
            v_total_amount,
            v_rating,
            v_review_text,
            v_mechanic_name,
            v_shop_name,
            NOW(),
            NOW()
        )
        ON CONFLICT (service_request_id, customer_id) DO UPDATE SET
            job_status = NEW.status,
            completed_at = CASE WHEN NEW.status = 'completed' THEN NOW() ELSE customer_job_history.completed_at END,
            cancelled_at = CASE WHEN NEW.status = 'cancelled' THEN NOW() ELSE customer_job_history.cancelled_at END,
            total_amount = v_total_amount,
            rating = v_rating,
            review_text = v_review_text,
            mechanic_name = v_mechanic_name,
            shop_name = v_shop_name,
            updated_at = NOW();
        
        RAISE NOTICE '✅ Added job % to history (Status: %)', NEW.title, NEW.status;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for job history
DROP TRIGGER IF EXISTS trg_service_request_history ON service_requests;
CREATE TRIGGER trg_service_request_history
    AFTER UPDATE ON service_requests
    FOR EACH ROW
    WHEN (NEW.status IN ('completed', 'cancelled'))
    EXECUTE FUNCTION add_job_to_history();

-- Backfill existing completed/cancelled jobs to history
DO $$
DECLARE
    v_service_request RECORD;
    v_mechanic_name text;
    v_shop_name text;
    v_shop_id uuid;
    v_total_amount decimal(10,2);
    v_rating decimal(2,1);
    v_review_text text;
    v_job_duration_minutes integer;
BEGIN
    RAISE NOTICE '📚 BACKFILLING EXISTING JOB HISTORY...';
    
    -- Loop through all completed/cancelled service requests
    FOR v_service_request IN
        SELECT 
            sr.*,
            p.amount as total_amount,
            r.rating,
            r.comment as review_text
        FROM service_requests sr
        LEFT JOIN payments p ON p.request_id = sr.id
        LEFT JOIN reviews r ON r.request_id = sr.id
        WHERE sr.status IN ('completed', 'cancelled')
        AND NOT EXISTS (
            SELECT 1 FROM customer_job_history cjh 
            WHERE cjh.service_request_id = sr.id
        )
    LOOP
        -- Get mechanic and shop details
        IF v_service_request.assigned_mechanic_id IS NOT NULL THEN
            SELECT 
                up.first_name || ' ' || up.last_name,
                s.shop_name,
                s.id
            INTO v_mechanic_name, v_shop_name, v_shop_id
            FROM user_profiles up
            LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
            LEFT JOIN shops s ON s.id = sm.shop_id
            WHERE up.id = v_service_request.assigned_mechanic_id;
        END IF;
        
        -- Calculate job duration
        IF v_service_request.status = 'completed' AND v_service_request.assigned_at IS NOT NULL THEN
            v_job_duration_minutes := EXTRACT(EPOCH FROM (v_service_request.updated_at - v_service_request.assigned_at)) / 60;
        END IF;
        
        -- Add to mechanic job history
        IF v_service_request.assigned_mechanic_id IS NOT NULL THEN
            INSERT INTO mechanic_job_history (
                mechanic_id,
                service_request_id,
                customer_id,
                shop_id,
                job_title,
                job_description,
                job_status,
                completed_at,
                cancelled_at,
                total_amount,
                rating,
                review_text,
                job_duration_minutes,
                created_at,
                updated_at
            ) VALUES (
                v_service_request.assigned_mechanic_id,
                v_service_request.id,
                v_service_request.customer_id,
                v_shop_id,
                v_service_request.title,
                v_service_request.description,
                v_service_request.status,
                CASE WHEN v_service_request.status = 'completed' THEN v_service_request.updated_at ELSE NULL END,
                CASE WHEN v_service_request.status = 'cancelled' THEN v_service_request.updated_at ELSE NULL END,
                v_service_request.total_amount,
                v_service_request.rating,
                v_service_request.review_text,
                v_job_duration_minutes,
                v_service_request.created_at,
                NOW()
            )
            ON CONFLICT (service_request_id, mechanic_id) DO NOTHING;
        END IF;
        
        -- Add to customer job history
        INSERT INTO customer_job_history (
            customer_id,
            service_request_id,
            mechanic_id,
            shop_id,
            job_title,
            job_description,
            job_status,
            completed_at,
            cancelled_at,
            total_amount,
            rating,
            review_text,
            mechanic_name,
            shop_name,
            created_at,
            updated_at
        ) VALUES (
            v_service_request.customer_id,
            v_service_request.id,
            v_service_request.assigned_mechanic_id,
            v_shop_id,
            v_service_request.title,
            v_service_request.description,
            v_service_request.status,
            CASE WHEN v_service_request.status = 'completed' THEN v_service_request.updated_at ELSE NULL END,
            CASE WHEN v_service_request.status = 'cancelled' THEN v_service_request.updated_at ELSE NULL END,
            v_service_request.total_amount,
            v_service_request.rating,
            v_service_request.review_text,
            v_mechanic_name,
            v_shop_name,
            v_service_request.created_at,
            NOW()
        )
        ON CONFLICT (service_request_id, customer_id) DO NOTHING;
        
    END LOOP;
END $$;

-- Create unique constraints for job history tables
DO $$
BEGIN
    -- Only add constraint if table exists and constraint doesn't exist
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'mechanic_job_history') 
    AND NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'mechanic_job_history_service_request_mechanic_key'
    ) THEN
        ALTER TABLE mechanic_job_history 
        ADD CONSTRAINT mechanic_job_history_service_request_mechanic_key 
        UNIQUE (service_request_id, mechanic_id);
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customer_job_history')
    AND NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'customer_job_history_service_request_customer_key'
    ) THEN
        ALTER TABLE customer_job_history 
        ADD CONSTRAINT customer_job_history_service_request_customer_key 
        UNIQUE (service_request_id, customer_id);
    END IF;
END $$;

-- Create views for easy access to job history
CREATE OR REPLACE VIEW v_mechanic_job_history AS
SELECT 
    mjh.*,
    customer.first_name || ' ' || customer.last_name as customer_name,
    customer.email as customer_email,
    s.shop_name,
    CASE 
        WHEN mjh.job_status = 'completed' THEN '✅ Completed'
        WHEN mjh.job_status = 'cancelled' THEN '❌ Cancelled'
        ELSE mjh.job_status
    END as status_display
FROM mechanic_job_history mjh
JOIN user_profiles customer ON customer.id = mjh.customer_id
LEFT JOIN shops s ON s.id = mjh.shop_id
ORDER BY mjh.created_at DESC;

CREATE OR REPLACE VIEW v_customer_job_history AS
SELECT 
    cjh.*,
    CASE 
        WHEN cjh.job_status = 'completed' THEN '✅ Completed'
        WHEN cjh.job_status = 'cancelled' THEN '❌ Cancelled'
        ELSE cjh.job_status
    END as status_display
FROM customer_job_history cjh
ORDER BY cjh.created_at DESC;

COMMIT;

-- Final completion message
DO $$
BEGIN
    RAISE NOTICE '🎉 MECHANIC-CUSTOMER CONNECTION SYSTEM COMPLETE!';
    RAISE NOTICE '';
    RAISE NOTICE 'Available views:';
    RAISE NOTICE '- SELECT * FROM v_mechanic_shop_connections;';
    RAISE NOTICE '- SELECT * FROM v_customer_mechanic_connections;';
    RAISE NOTICE '- SELECT * FROM v_mechanic_job_history;';
    RAISE NOTICE '- SELECT * FROM v_customer_job_history;';
    RAISE NOTICE '';
    RAISE NOTICE 'Validation function:';
    RAISE NOTICE '- SELECT * FROM validate_connection_integrity();';
    RAISE NOTICE '';
    RAISE NOTICE 'Job History Features:';
    RAISE NOTICE '- ✅ Automatic history tracking for completed/cancelled jobs';
    RAISE NOTICE '- ✅ Mechanic job history with ratings and earnings';
    RAISE NOTICE '- ✅ Customer job history with service details';
    RAISE NOTICE '- ✅ Backfilled existing completed/cancelled jobs';
    RAISE NOTICE '';
    RAISE NOTICE 'Auto-triggers enabled for future connections! ✅';
END $$;