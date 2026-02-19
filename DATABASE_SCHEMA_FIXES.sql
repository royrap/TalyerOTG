-- ====================================================================
-- DATABASE SCHEMA FIXES AND IMPROVEMENTS
-- ====================================================================
-- This file contains fixes for foreign key constraints, data types, 
-- and table relationships found in the provided schema.

-- ====================================================================
-- 1. FIX MISSING EXTENSIONS
-- ====================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis"; -- For spatial operations if needed

-- ====================================================================
-- 2. FIX FOREIGN KEY CONSTRAINT ISSUES
-- ====================================================================

-- Fix invoice table foreign key issue with provider_id
ALTER TABLE public.invoices 
DROP CONSTRAINT IF EXISTS invoices_provider_id_fkey;

ALTER TABLE public.invoices 
ADD CONSTRAINT invoices_provider_id_fkey 
FOREIGN KEY (provider_id) REFERENCES public.service_providers(id) ON DELETE SET NULL;

-- Fix mechanic_availability_status shop_id constraint
ALTER TABLE public.mechanic_availability_status 
DROP CONSTRAINT IF EXISTS mechanic_availability_status_shop_id_fkey;

ALTER TABLE public.mechanic_availability_status 
ADD CONSTRAINT mechanic_availability_status_shop_id_fkey 
FOREIGN KEY (shop_id) REFERENCES public.shops(id) ON DELETE SET NULL;

-- ====================================================================
-- 3. ADD MISSING FIELDS TO EXISTING TABLES
-- ====================================================================

-- Add missing fields to shops table for better location tracking
ALTER TABLE public.shops 
ADD COLUMN IF NOT EXISTS business_hours jsonb DEFAULT '{"monday": {"open": "08:00", "close": "18:00"}, "tuesday": {"open": "08:00", "close": "18:00"}, "wednesday": {"open": "08:00", "close": "18:00"}, "thursday": {"open": "08:00", "close": "18:00"}, "friday": {"open": "08:00", "close": "18:00"}, "saturday": {"open": "08:00", "close": "16:00"}, "sunday": {"open": null, "close": null}}'::jsonb,
ADD COLUMN IF NOT EXISTS emergency_contact text,
ADD COLUMN IF NOT EXISTS max_concurrent_jobs integer DEFAULT 10,
ADD COLUMN IF NOT EXISTS current_job_count integer DEFAULT 0;

-- Add missing fields to service_providers for better tracking
ALTER TABLE public.service_providers 
ADD COLUMN IF NOT EXISTS last_online_at timestamp with time zone DEFAULT now(),
ADD COLUMN IF NOT EXISTS response_time_avg_minutes integer DEFAULT 30,
ADD COLUMN IF NOT EXISTS completion_rate_percentage numeric DEFAULT 100.0,
ADD COLUMN IF NOT EXISTS cancellation_rate_percentage numeric DEFAULT 0.0;

-- Add missing fields to user_profiles for better user management
ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS timezone text DEFAULT 'Asia/Manila',
ADD COLUMN IF NOT EXISTS preferred_language text DEFAULT 'en',
ADD COLUMN IF NOT EXISTS notification_preferences jsonb DEFAULT '{"push": true, "email": true, "sms": false}'::jsonb;

-- ====================================================================
-- 4. IMPROVE ENUM CONSTRAINTS
-- ====================================================================

-- Update service_requests status enum to be more comprehensive
ALTER TABLE public.service_requests 
DROP CONSTRAINT IF EXISTS service_requests_status_check;

ALTER TABLE public.service_requests 
ADD CONSTRAINT service_requests_status_check 
CHECK (status::text = ANY (ARRAY[
    'pending'::text, 
    'awaiting_payment'::text, 
    'paid'::text, 
    'ready_to_assign'::text, 
    'accepted'::text, 
    'rejected'::text, 
    'assigned'::text, 
    'mechanic_assigned'::text, 
    'payment_completed'::text, 
    'in_progress'::text, 
    'inspection_started'::text,
    'inspection_completed'::text, 
    'estimate_provided'::text,
    'estimate_approved'::text,
    'invoice_sent'::text, 
    'invoice_accepted'::text, 
    'invoice_paid'::text, 
    'work_started'::text,
    'work_completed'::text,
    'awaiting_completion'::text, 
    'completed'::text, 
    'cancelled'::text
]));

-- Update payment_status enum
ALTER TABLE public.service_requests 
DROP CONSTRAINT IF EXISTS service_requests_payment_status_check;

ALTER TABLE public.service_requests 
ADD CONSTRAINT service_requests_payment_status_check 
CHECK (payment_status::text = ANY (ARRAY[
    'pending'::text, 
    'pending_payment'::text, 
    'processing'::text, 
    'validating'::text,
    'completed'::text, 
    'failed'::text, 
    'refunded'::text,
    'disputed'::text
]));

-- ====================================================================
-- 5. ADD DATA VALIDATION CONSTRAINTS
-- ====================================================================

-- Add check constraints for latitude and longitude
ALTER TABLE public.shops 
ADD CONSTRAINT shops_latitude_check CHECK (latitude >= -90 AND latitude <= 90),
ADD CONSTRAINT shops_longitude_check CHECK (longitude >= -180 AND longitude <= 180);

ALTER TABLE public.service_requests 
ADD CONSTRAINT service_requests_pickup_latitude_check CHECK (pickup_latitude >= -90 AND pickup_latitude <= 90),
ADD CONSTRAINT service_requests_pickup_longitude_check CHECK (pickup_longitude >= -180 AND pickup_longitude <= 180);

ALTER TABLE public.service_providers 
ADD CONSTRAINT service_providers_current_latitude_check CHECK (current_latitude IS NULL OR (current_latitude >= -90 AND current_latitude <= 90)),
ADD CONSTRAINT service_providers_current_longitude_check CHECK (current_longitude IS NULL OR (current_longitude >= -180 AND current_longitude <= 180));

-- Add check constraints for pricing
ALTER TABLE public.service_requests 
ADD CONSTRAINT service_requests_estimated_price_check CHECK (estimated_price IS NULL OR estimated_price >= 0),
ADD CONSTRAINT service_requests_final_price_check CHECK (final_price IS NULL OR final_price >= 0),
ADD CONSTRAINT service_requests_service_fee_check CHECK (service_fee IS NULL OR service_fee >= 0);

ALTER TABLE public.service_categories 
ADD CONSTRAINT service_categories_base_price_check CHECK (base_price IS NULL OR base_price >= 0);

-- ====================================================================
-- 6. CREATE MISSING INDEXES FOR PERFORMANCE
-- ====================================================================

-- Indexes for service_requests table
CREATE INDEX IF NOT EXISTS idx_service_requests_customer_id ON public.service_requests(customer_id);
CREATE INDEX IF NOT EXISTS idx_service_requests_provider_id ON public.service_requests(provider_id) WHERE provider_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_service_requests_status ON public.service_requests(status);
CREATE INDEX IF NOT EXISTS idx_service_requests_created_at ON public.service_requests(created_at);
CREATE INDEX IF NOT EXISTS idx_service_requests_location ON public.service_requests(pickup_latitude, pickup_longitude);

-- Indexes for user_profiles table
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_type ON public.user_profiles(user_type);
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON public.user_profiles(email);
CREATE INDEX IF NOT EXISTS idx_user_profiles_phone ON public.user_profiles(phone_number);

-- Indexes for service_providers table
CREATE INDEX IF NOT EXISTS idx_service_providers_user_id ON public.service_providers(user_id);
CREATE INDEX IF NOT EXISTS idx_service_providers_status ON public.service_providers(status);
CREATE INDEX IF NOT EXISTS idx_service_providers_location ON public.service_providers(current_latitude, current_longitude) WHERE current_latitude IS NOT NULL;

-- Indexes for shops table
CREATE INDEX IF NOT EXISTS idx_shops_owner_id ON public.shops(owner_id);
CREATE INDEX IF NOT EXISTS idx_shops_location ON public.shops(latitude, longitude) WHERE latitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_shops_current_status ON public.shops(current_status);

-- Indexes for payments table
CREATE INDEX IF NOT EXISTS idx_payments_request_id ON public.payments(request_id);
CREATE INDEX IF NOT EXISTS idx_payments_customer_id ON public.payments(customer_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON public.payments(status);

-- ====================================================================
-- 7. CREATE UPDATED VIEWS FOR EASIER QUERYING
-- ====================================================================

-- View for active service requests with details
CREATE OR REPLACE VIEW active_service_requests AS
SELECT 
    sr.id,
    sr.title,
    sr.description,
    sr.status,
    sr.payment_status,
    sr.pickup_address,
    sr.pickup_latitude,
    sr.pickup_longitude,
    sr.estimated_price,
    sr.created_at,
    -- Customer details
    c.first_name || ' ' || c.last_name as customer_name,
    c.phone_number as customer_phone,
    c.email as customer_email,
    -- Provider details (if assigned)
    p.first_name || ' ' || p.last_name as provider_name,
    sp.company_name as provider_company,
    -- Shop details (if shop-based)
    s.shop_name,
    s.shop_address,
    s.shop_phone,
    -- Service category
    sc.name as service_category,
    sc.estimated_duration,
    -- Distance and location info
    sr.distance_km,
    sr.estimated_arrival_minutes
FROM public.service_requests sr
JOIN public.user_profiles c ON c.id = sr.customer_id
LEFT JOIN public.service_providers sp ON sp.id = sr.provider_id
LEFT JOIN public.user_profiles p ON p.id = sp.user_id
LEFT JOIN public.shops s ON s.id = sr.shop_id
LEFT JOIN public.service_categories sc ON sc.id = sr.category_id
WHERE sr.status NOT IN ('completed', 'cancelled');

-- View for provider performance metrics
CREATE OR REPLACE VIEW provider_performance_metrics AS
SELECT 
    sp.id as provider_id,
    up.first_name || ' ' || up.last_name as provider_name,
    sp.company_name,
    sp.rating,
    sp.total_reviews,
    sp.years_experience,
    -- Request metrics
    COUNT(sr.id) as total_requests,
    COUNT(CASE WHEN sr.status = 'completed' THEN 1 END) as completed_requests,
    COUNT(CASE WHEN sr.status = 'cancelled' THEN 1 END) as cancelled_requests,
    -- Performance calculations
    ROUND(
        (COUNT(CASE WHEN sr.status = 'completed' THEN 1 END)::numeric / 
         NULLIF(COUNT(sr.id), 0) * 100), 2
    ) as completion_rate_percentage,
    -- Average response time
    AVG(
        CASE 
            WHEN sr.accepted_at IS NOT NULL 
            THEN EXTRACT(EPOCH FROM (sr.accepted_at - sr.created_at)) / 60
        END
    ) as avg_response_time_minutes,
    -- Revenue metrics
    SUM(CASE WHEN sr.status = 'completed' THEN sr.final_price END) as total_revenue,
    AVG(CASE WHEN sr.status = 'completed' THEN sr.final_price END) as avg_job_value
FROM public.service_providers sp
JOIN public.user_profiles up ON up.id = sp.user_id
LEFT JOIN public.service_requests sr ON sr.provider_id = sp.id
WHERE sp.is_verified = true
GROUP BY sp.id, up.first_name, up.last_name, sp.company_name, sp.rating, sp.total_reviews, sp.years_experience;

-- ====================================================================
-- 8. CREATE FUNCTIONS FOR DATA INTEGRITY
-- ====================================================================

-- Function to update provider statistics
CREATE OR REPLACE FUNCTION update_provider_statistics()
RETURNS trigger AS $$
BEGIN
    -- Update service provider stats when a request is completed
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        UPDATE public.service_providers 
        SET 
            total_reviews = total_reviews + 1,
            -- Update other stats as needed
            updated_at = now()
        WHERE id = NEW.provider_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for auto-updating provider stats
DROP TRIGGER IF EXISTS update_provider_stats_trigger ON public.service_requests;
CREATE TRIGGER update_provider_stats_trigger
    AFTER UPDATE ON public.service_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_provider_statistics();

-- ====================================================================
-- 9. CREATE FUNCTION TO CLEAN UP OLD DATA
-- ====================================================================

CREATE OR REPLACE FUNCTION cleanup_old_data()
RETURNS void AS $$
BEGIN
    -- Clean up old notifications (older than 30 days)
    DELETE FROM public.notifications 
    WHERE created_at < now() - interval '30 days';
    
    -- Clean up old security logs (older than 90 days)
    DELETE FROM public.account_security_logs 
    WHERE created_at < now() - interval '90 days';
    
    -- Clean up old audit logs (older than 1 year)
    DELETE FROM public.audit_logs 
    WHERE created_at < now() - interval '1 year';
    
    -- Clean up expired password reset tokens
    DELETE FROM public.password_reset_tokens 
    WHERE expires_at < now() OR used_at IS NOT NULL;
    
    -- Clean up expired email verification tokens
    DELETE FROM public.email_verification_tokens 
    WHERE expires_at < now() OR used_at IS NOT NULL;
    
    -- Clean up old temporary passwords
    DELETE FROM public.temporary_passwords 
    WHERE expires_at < now() OR used_at IS NOT NULL;
    
    -- Archive completed service requests older than 1 year
    -- (You might want to move them to an archive table instead of deleting)
    
END;
$$ LANGUAGE plpgsql;

-- ====================================================================
-- 10. ADD ROW LEVEL SECURITY POLICIES (OPTIONAL)
-- ====================================================================

-- Enable RLS on sensitive tables
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Example policies (adjust based on your security requirements)

-- Users can only see their own profile
CREATE POLICY user_profiles_policy ON public.user_profiles
    FOR ALL USING (auth.uid() = id);

-- Users can see service requests they're involved in
CREATE POLICY service_requests_policy ON public.service_requests
    FOR ALL USING (
        auth.uid() = customer_id OR 
        auth.uid() = assigned_mechanic_id OR
        auth.uid() IN (
            SELECT user_id FROM public.service_providers 
            WHERE id = provider_id
        )
    );

-- Payment access policy
CREATE POLICY payments_policy ON public.payments
    FOR ALL USING (
        auth.uid() = customer_id OR
        auth.uid() IN (
            SELECT user_id FROM public.service_providers 
            WHERE id = provider_id
        )
    );

-- ====================================================================
-- FINAL NOTES
-- ====================================================================
/*
These fixes address:

1. ✅ Missing foreign key constraints
2. ✅ Better enum constraints for status fields
3. ✅ Data validation constraints for coordinates and pricing
4. ✅ Performance indexes for common queries
5. ✅ Useful views for reporting and analytics
6. ✅ Automatic statistics updating
7. ✅ Data cleanup functions
8. ✅ Row Level Security policies

Remember to test these changes in a development environment first!

To apply these fixes:
1. Run this SQL file in your Supabase SQL editor
2. Test the broadcast request system
3. Update your Flutter app to use the new fields and functions
4. Set up periodic cleanup jobs
*/