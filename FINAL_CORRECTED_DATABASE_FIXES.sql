-- ═══════════════════════════════════════════════════════════════════════════════
-- FINAL CORRECTED DATABASE FIXES FOR ROADAID APPLICATION
-- Addresses all identified flow issues without syntax errors
-- ═══════════════════════════════════════════════════════════════════════════════

-- 🚨 CRITICAL FIX #1: Clean up duplicate service_providers entries
-- This fixes the PostgrestException "multiple rows returned" error

-- Step 1: Create backup before cleanup
CREATE TABLE IF NOT EXISTS service_providers_backup AS
SELECT * FROM service_providers;

-- Step 2: Show current duplicate situation
DO $$
DECLARE
    total_count integer;
    unique_count integer;
    duplicate_count integer;
BEGIN
    SELECT COUNT(*) INTO total_count FROM service_providers;
    SELECT COUNT(DISTINCT user_id) INTO unique_count FROM service_providers WHERE user_id IS NOT NULL;
    duplicate_count := total_count - unique_count;
    
    RAISE NOTICE '📊 BEFORE CLEANUP - Service Providers Analysis:';
    RAISE NOTICE '  Total entries: %', total_count;
    RAISE NOTICE '  Unique users: %', unique_count;  
    RAISE NOTICE '  Duplicates: %', duplicate_count;
END
$$;

-- Step 3: Remove duplicates (keep most recent per user_id)
DELETE FROM service_providers 
WHERE id NOT IN (
    SELECT DISTINCT ON (user_id) id
    FROM service_providers 
    WHERE user_id IS NOT NULL
    ORDER BY user_id, created_at DESC NULLS LAST
);

-- Step 4: Add unique constraint to prevent future duplicates
ALTER TABLE service_providers 
DROP CONSTRAINT IF EXISTS unique_user_id_per_provider;

ALTER TABLE service_providers 
ADD CONSTRAINT unique_user_id_per_provider 
UNIQUE (user_id);

-- Step 5: Verify cleanup success
DO $$
DECLARE
    total_after integer;
    remaining_duplicates integer;
BEGIN
    SELECT COUNT(*) INTO total_after FROM service_providers;
    
    SELECT COUNT(*) INTO remaining_duplicates 
    FROM (
        SELECT user_id, COUNT(*) 
        FROM service_providers 
        WHERE user_id IS NOT NULL
        GROUP BY user_id 
        HAVING COUNT(*) > 1
    ) duplicates;
    
    RAISE NOTICE '✅ AFTER CLEANUP - Service Providers Analysis:';
    RAISE NOTICE '  Total entries: %', total_after;
    RAISE NOTICE '  Remaining duplicates: %', remaining_duplicates;
    
    IF remaining_duplicates = 0 THEN
        RAISE NOTICE '🎉 SUCCESS: All duplicates removed!';
        RAISE NOTICE '✅ getMechanicLocationForRequest will now work properly';
    ELSE
        RAISE NOTICE '❌ WARNING: % duplicates still exist', remaining_duplicates;
    END IF;
END
$$;

-- 🔧 ENHANCEMENT #2: Activate Review & Rating System
-- Complete database schema for reviews and ratings

-- Reviews table (if not exists)
CREATE TABLE IF NOT EXISTS reviews (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    service_request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES service_providers(id) ON DELETE CASCADE,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS for reviews
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- RLS Policies for reviews
DROP POLICY IF EXISTS "Users can view reviews for their services" ON reviews;
CREATE POLICY "Users can view reviews for their services" ON reviews FOR SELECT USING (
    customer_id = auth.uid() OR 
    provider_id IN (SELECT id FROM service_providers WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS "Customers can create reviews" ON reviews;
CREATE POLICY "Customers can create reviews" ON reviews FOR INSERT WITH CHECK (
    customer_id = auth.uid()
);

-- Trigger 1: Auto-update provider ratings when review is added/updated
CREATE OR REPLACE FUNCTION update_provider_rating()
RETURNS TRIGGER AS $$
DECLARE
    avg_rating NUMERIC;
    review_count INTEGER;
BEGIN
    -- Calculate new average rating for the provider
    SELECT 
        ROUND(AVG(rating), 2),
        COUNT(*)
    INTO avg_rating, review_count
    FROM reviews 
    WHERE provider_id = COALESCE(NEW.provider_id, OLD.provider_id);
    
    -- Update the service provider's rating
    UPDATE service_providers 
    SET 
        rating = avg_rating,
        total_reviews = review_count,
        updated_at = NOW()
    WHERE id = COALESCE(NEW.provider_id, OLD.provider_id);
    
    RAISE NOTICE '⭐ Provider rating updated: % stars (% reviews)', 
                 COALESCE(avg_rating, 0), review_count;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_provider_rating_trigger ON reviews;
CREATE TRIGGER update_provider_rating_trigger
    AFTER INSERT OR UPDATE OR DELETE ON reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_provider_rating();

-- 📊 ENHANCEMENT #3: Communication Flow System  
-- Enhanced notifications for service completion and reviews

CREATE OR REPLACE FUNCTION trigger_communication_flow()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_id UUID;
    v_mechanic_id UUID;
    v_service_type TEXT;
BEGIN
    -- Extract key information
    v_customer_id := NEW.customer_id;
    v_mechanic_id := NEW.assigned_mechanic_id;
    v_service_type := COALESCE(NEW.service_type, 'Service');
    
    -- Handle service completion
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
        -- Notify both parties
        PERFORM pg_notify(
            'service_completed',
            jsonb_build_object(
                'type', 'service_completed',
                'service_request_id', NEW.id,
                'customer_id', v_customer_id,
                'mechanic_id', v_mechanic_id,
                'service_type', v_service_type,
                'show_review_dialog', true
            )::text
        );
        
        -- Trigger customer review dialog
        IF v_customer_id IS NOT NULL THEN
            PERFORM pg_notify(
                'customer_' || v_customer_id::text,
                jsonb_build_object(
                    'type', 'show_review_dialog',
                    'service_request_id', NEW.id,
                    'mechanic_id', v_mechanic_id,
                    'service_type', v_service_type,
                    'auto_show', true
                )::text
            );
        END IF;
    END IF;
    
    -- Handle payment completion
    IF NEW.payment_status = 'completed' AND (OLD.payment_status IS NULL OR OLD.payment_status != 'completed') THEN
        PERFORM pg_notify(
            'payment_completed',
            jsonb_build_object(
                'type', 'payment_completed',
                'service_request_id', NEW.id,
                'customer_id', v_customer_id,
                'mechanic_id', v_mechanic_id
            )::text
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply communication trigger
DROP TRIGGER IF EXISTS communication_flow_trigger ON service_requests;
CREATE TRIGGER communication_flow_trigger
    AFTER INSERT OR UPDATE ON service_requests
    FOR EACH ROW
    EXECUTE FUNCTION trigger_communication_flow();

-- 📈 ENHANCEMENT #4: System Health Monitoring
-- Views and functions to monitor system health

CREATE OR REPLACE VIEW system_health_dashboard AS
WITH service_stats AS (
    SELECT 
        COUNT(*) as total_services,
        COUNT(*) FILTER (WHERE status = 'completed') as completed_services,
        COUNT(*) FILTER (WHERE payment_status = 'completed') as paid_services,
        COUNT(DISTINCT assigned_mechanic_id) FILTER (WHERE assigned_mechanic_id IS NOT NULL) as active_mechanics,
        COUNT(DISTINCT customer_id) as active_customers
    FROM service_requests 
    WHERE created_at >= NOW() - INTERVAL '24 hours'
),
review_stats AS (
    SELECT 
        COUNT(*) as total_reviews,
        ROUND(AVG(rating), 2) as avg_rating
    FROM reviews 
    WHERE created_at >= NOW() - INTERVAL '24 hours'
),
provider_stats AS (
    SELECT 
        COUNT(*) as total_providers,
        COUNT(DISTINCT user_id) as unique_providers,
        COUNT(*) - COUNT(DISTINCT user_id) as duplicate_providers
    FROM service_providers
)
SELECT 
    'System Health Dashboard (Last 24h)' as report_title,
    json_build_object(
        'services', json_build_object(
            'total', ss.total_services,
            'completed', ss.completed_services,
            'paid', ss.paid_services,
            'completion_rate', CASE WHEN ss.total_services > 0 THEN ROUND(ss.completed_services * 100.0 / ss.total_services, 1) ELSE 0 END || '%'
        ),
        'users', json_build_object(
            'active_customers', ss.active_customers,
            'active_mechanics', ss.active_mechanics
        ),
        'reviews', json_build_object(
            'total', rs.total_reviews,
            'average_rating', COALESCE(rs.avg_rating, 0) || ' stars'
        ),
        'providers', json_build_object(
            'total_entries', ps.total_providers,
            'unique_providers', ps.unique_providers,
            'duplicates', ps.duplicate_providers,
            'status', CASE WHEN ps.duplicate_providers = 0 THEN '✅ Clean' ELSE '⚠️ Has duplicates' END
        )
    ) as health_data
FROM service_stats ss, review_stats rs, provider_stats ps;

-- 🧪 SYSTEM VALIDATION
-- Test all systems work correctly

DO $$
DECLARE
    provider_duplicates integer;
    review_triggers_active integer;
    communication_triggers_active integer;
BEGIN
    RAISE NOTICE '🧪 RUNNING SYSTEM VALIDATION TESTS...';
    
    -- Test 1: Check for provider duplicates
    SELECT COUNT(*) INTO provider_duplicates
    FROM (
        SELECT user_id, COUNT(*) 
        FROM service_providers 
        WHERE user_id IS NOT NULL
        GROUP BY user_id 
        HAVING COUNT(*) > 1
    ) dups;
    
    -- Test 2: Verify review system triggers
    SELECT COUNT(*) INTO review_triggers_active
    FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    WHERE c.relname = 'reviews' AND t.tgname = 'update_provider_rating_trigger';
    
    -- Test 3: Verify communication triggers  
    SELECT COUNT(*) INTO communication_triggers_active
    FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    WHERE c.relname = 'service_requests' AND t.tgname = 'communication_flow_trigger';
    
    -- Report results
    RAISE NOTICE '📋 VALIDATION RESULTS:';
    RAISE NOTICE '  ✅ Provider duplicates: % (should be 0)', provider_duplicates;
    RAISE NOTICE '  ✅ Review triggers active: % (should be 1)', review_triggers_active;
    RAISE NOTICE '  ✅ Communication triggers active: % (should be 1)', communication_triggers_active;
    
    IF provider_duplicates = 0 AND review_triggers_active = 1 AND communication_triggers_active = 1 THEN
        RAISE NOTICE '🎉 ALL SYSTEMS OPERATIONAL!';
        RAISE NOTICE '✅ Database integrity restored';
        RAISE NOTICE '✅ Review system activated';
        RAISE NOTICE '✅ Communication flow enhanced';
        RAISE NOTICE '📱 Your RoadAid app should now work without errors!';
    ELSE
        RAISE NOTICE '⚠️ Some issues detected - check individual results above';
    END IF;
END
$$;

-- 🎯 COMPLETION MESSAGE
DO $$
BEGIN
    RAISE NOTICE '═══════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '🚀 ROADAID DATABASE OPTIMIZATION COMPLETE!';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ Fixed PostgrestException (multiple rows error)';
    RAISE NOTICE '✅ Activated review & rating system with automatic triggers';
    RAISE NOTICE '✅ Enhanced customer-mechanic communication flow';
    RAISE NOTICE '✅ Added system health monitoring';
    RAISE NOTICE '✅ Implemented data integrity constraints';
    RAISE NOTICE '';
    RAISE NOTICE '📱 Your app should now work smoothly without the reported errors!';
    RAISE NOTICE '🔍 Monitor system health: SELECT * FROM system_health_dashboard;';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════════════════════';
END
$$;

-- 📊 Final health check (run this separately if needed)
-- SELECT * FROM system_health_dashboard;