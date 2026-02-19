-- ========================================
-- ROADAID DATABASE - POSTGRESQL/SUPABASE
-- ========================================
-- Generated: October 10, 2025
-- Total Tables: 39
-- Database: PostgreSQL 15+ (Supabase)
-- ========================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- ========================================
-- 1. CORE ENTITY TABLES
-- ========================================

-- Note: auth.users table is managed by Supabase Auth
-- We only need to reference it via foreign keys

-- User Profiles (extends auth.users)
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone_number VARCHAR(20),
    user_type VARCHAR(20) CHECK (user_type IN ('customer', 'mechanic', 'talyer_owner', 'admin')),
    profile_image_url TEXT,
    current_latitude NUMERIC(10,8),
    current_longitude NUMERIC(11,8),
    shop_id UUID,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'banned')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_profiles_user_type ON user_profiles(user_type);
CREATE INDEX idx_user_profiles_status ON user_profiles(status);
CREATE INDEX idx_user_profiles_location ON user_profiles USING GIST (
    ll_to_earth(current_latitude, current_longitude)
);

COMMENT ON TABLE user_profiles IS 'User profile details for all user types';

-- Shops / Talyer
CREATE TABLE shops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID UNIQUE REFERENCES user_profiles(id) ON DELETE CASCADE,
    shop_name VARCHAR(255) NOT NULL,
    shop_address TEXT,
    shop_phone VARCHAR(20),
    shop_email VARCHAR(255),
    latitude NUMERIC(10,8),
    longitude NUMERIC(11,8),
    service_radius NUMERIC(5,2) DEFAULT 15,
    business_hours JSONB,
    current_status VARCHAR(20) DEFAULT 'closed' CHECK (current_status IN ('open', 'closed', 'busy')),
    rating NUMERIC(3,2) DEFAULT 0 CHECK (rating >= 0 AND rating <= 5),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_shops_owner_id ON shops(owner_id);
CREATE INDEX idx_shops_current_status ON shops(current_status);
CREATE INDEX idx_shops_location ON shops USING GIST (
    ll_to_earth(latitude, longitude)
);

COMMENT ON TABLE shops IS 'Auto repair shops / talyer';

-- Add foreign key to user_profiles.shop_id
ALTER TABLE user_profiles ADD CONSTRAINT fk_user_profiles_shop 
    FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE SET NULL;

-- Service Providers (Mechanics)
CREATE TABLE service_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES user_profiles(id) ON DELETE CASCADE,
    shop_id UUID REFERENCES shops(id) ON DELETE SET NULL,
    talyer_owner_id UUID REFERENCES user_profiles(id),
    company_name VARCHAR(255),
    rating NUMERIC(3,2) DEFAULT 0 CHECK (rating >= 0 AND rating <= 5),
    service_radius NUMERIC(5,2) DEFAULT 15,
    is_verified BOOLEAN DEFAULT FALSE,
    is_available BOOLEAN DEFAULT TRUE,
    current_latitude NUMERIC(10,8),
    current_longitude NUMERIC(11,8),
    status VARCHAR(20) DEFAULT 'offline' CHECK (status IN ('offline', 'available', 'busy')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_service_providers_user_id ON service_providers(user_id);
CREATE INDEX idx_service_providers_shop_id ON service_providers(shop_id);
CREATE INDEX idx_service_providers_status ON service_providers(status);

COMMENT ON TABLE service_providers IS 'Mechanics (shop-based or independent)';

-- Vehicles
CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    brand_name VARCHAR(100),
    model_name VARCHAR(100),
    year INTEGER,
    plate_number VARCHAR(20),
    vehicle_type VARCHAR(50) CHECK (vehicle_type IN ('car', 'motorcycle', 'truck')),
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_vehicles_user_id ON vehicles(user_id);
CREATE INDEX idx_vehicles_plate_number ON vehicles(plate_number);

COMMENT ON TABLE vehicles IS 'Customer vehicles';

-- ========================================
-- 2. SERVICE MANAGEMENT TABLES
-- ========================================

-- Service Categories
CREATE TABLE service_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    base_price NUMERIC(10,2),
    estimated_duration INTEGER,
    category_type VARCHAR(20) CHECK (category_type IN ('standard', 'specialized', 'emergency')),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE service_categories IS 'Master list of service types';

-- Service Requests
CREATE TABLE service_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES service_providers(id) ON DELETE SET NULL,
    vehicle_id UUID REFERENCES vehicles(id),
    category_id UUID REFERENCES service_categories(id),
    shop_id UUID REFERENCES shops(id) ON DELETE SET NULL,
    assigned_mechanic_id UUID REFERENCES user_profiles(id),
    title VARCHAR(255),
    description TEXT,
    status VARCHAR(30) DEFAULT 'pending',
    pickup_latitude NUMERIC(10,8),
    pickup_longitude NUMERIC(11,8),
    pickup_address TEXT,
    service_fee NUMERIC(10,2),
    estimated_price NUMERIC(10,2),
    final_price NUMERIC(10,2),
    payment_status VARCHAR(20) DEFAULT 'unpaid',
    request_type VARCHAR(20) CHECK (request_type IN ('direct_mechanic', 'shop_based', 'broadcast')),
    is_broadcast_request BOOLEAN DEFAULT FALSE,
    broadcast_radius_km NUMERIC(5,2) DEFAULT 15,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX idx_service_requests_customer_id ON service_requests(customer_id);
CREATE INDEX idx_service_requests_provider_id ON service_requests(provider_id);
CREATE INDEX idx_service_requests_shop_id ON service_requests(shop_id);
CREATE INDEX idx_service_requests_status ON service_requests(status);
CREATE INDEX idx_service_requests_payment_status ON service_requests(payment_status);

COMMENT ON TABLE service_requests IS 'Service request from customers';

-- Shop Services
CREATE TABLE shop_services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID REFERENCES shops(id) ON DELETE CASCADE,
    category_id UUID REFERENCES service_categories(id),
    service_name VARCHAR(255),
    description TEXT,
    base_price NUMERIC(10,2),
    custom_price NUMERIC(10,2),
    estimated_duration INTEGER,
    is_active BOOLEAN DEFAULT TRUE,
    availability_status VARCHAR(30) DEFAULT 'available',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_shop_services_shop_id ON shop_services(shop_id);
CREATE INDEX idx_shop_services_category_id ON shop_services(category_id);

COMMENT ON TABLE shop_services IS 'Services offered by shops';

-- ========================================
-- 3. FINANCIAL TABLES
-- ========================================

-- Invoices
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES user_profiles(id),
    mechanic_id UUID REFERENCES user_profiles(id),
    talyer_owner_id UUID REFERENCES user_profiles(id),
    provider_id UUID REFERENCES service_providers(id),
    invoice_number VARCHAR(50) UNIQUE NOT NULL,
    subtotal NUMERIC(10,2),
    platform_fee NUMERIC(10,2),
    total_amount NUMERIC(10,2),
    talyer_net_amount NUMERIC(10,2),
    provider_net_amount NUMERIC(10,2),
    status VARCHAR(20) DEFAULT 'generated',
    selected_payment_method VARCHAR(20),
    payment_details JSONB,
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    paid_at TIMESTAMPTZ
);

CREATE INDEX idx_invoices_request_id ON invoices(request_id);
CREATE UNIQUE INDEX idx_invoices_invoice_number ON invoices(invoice_number);

COMMENT ON TABLE invoices IS 'Invoices for completed services';

-- Payments
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES user_profiles(id),
    provider_id UUID REFERENCES service_providers(id),
    invoice_id UUID REFERENCES invoices(id),
    amount NUMERIC(10,2),
    platform_fee NUMERIC(10,2),
    provider_amount NUMERIC(10,2),
    payment_method VARCHAR(20),
    transaction_id VARCHAR(100) UNIQUE,
    status VARCHAR(20) DEFAULT 'pending',
    payment_gateway VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    paid_at TIMESTAMPTZ
);

CREATE INDEX idx_payments_invoice_id ON payments(invoice_id);
CREATE UNIQUE INDEX idx_payments_transaction_id ON payments(transaction_id);

COMMENT ON TABLE payments IS 'Payment records';

-- Payment Releases
CREATE TABLE payment_releases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID UNIQUE REFERENCES payments(id) ON DELETE CASCADE,
    request_id UUID REFERENCES service_requests(id),
    provider_id UUID REFERENCES service_providers(id),
    customer_id UUID REFERENCES user_profiles(id),
    admin_id UUID REFERENCES auth.users(id),
    total_amount NUMERIC(10,2),
    platform_fee NUMERIC(10,2),
    provider_amount NUMERIC(10,2),
    release_status VARCHAR(20) DEFAULT 'pending',
    release_method VARCHAR(20),
    approved_at TIMESTAMPTZ,
    released_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE payment_releases IS 'Payment releases to providers';

-- Cash Payment Verifications
CREATE TABLE cash_payment_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID UNIQUE REFERENCES invoices(id) ON DELETE CASCADE,
    payment_id UUID UNIQUE REFERENCES payments(id) ON DELETE CASCADE,
    request_id UUID REFERENCES service_requests(id),
    customer_id UUID REFERENCES user_profiles(id),
    mechanic_id UUID REFERENCES user_profiles(id),
    verified_by UUID REFERENCES auth.users(id),
    cash_amount NUMERIC(10,2),
    cash_photo_url TEXT,
    receipt_photo_url TEXT,
    verification_status VARCHAR(20) DEFAULT 'pending',
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE cash_payment_verifications IS 'Cash payment verification records';

-- ========================================
-- 4. JOB HISTORY TABLES
-- ========================================

-- Mechanic Job History
CREATE TABLE mechanic_job_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mechanic_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    service_request_id UUID UNIQUE REFERENCES service_requests(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES user_profiles(id),
    shop_id UUID REFERENCES shops(id),
    job_title VARCHAR(255),
    job_description TEXT,
    job_status VARCHAR(20),
    completed_at TIMESTAMPTZ,
    total_amount NUMERIC(10,2),
    mechanic_earnings NUMERIC(10,2),
    shop_earnings NUMERIC(10,2),
    platform_fee NUMERIC(10,2),
    rating NUMERIC(2,1),
    review_text TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_mechanic_job_history_mechanic_id ON mechanic_job_history(mechanic_id);
CREATE INDEX idx_mechanic_job_history_service_request_id ON mechanic_job_history(service_request_id);

COMMENT ON TABLE mechanic_job_history IS 'Mechanic job history records';

-- Customer Job History
CREATE TABLE customer_job_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    service_request_id UUID UNIQUE REFERENCES service_requests(id) ON DELETE CASCADE,
    mechanic_id UUID REFERENCES user_profiles(id),
    shop_id UUID REFERENCES shops(id),
    job_title VARCHAR(255),
    job_description TEXT,
    job_status VARCHAR(20),
    completed_at TIMESTAMPTZ,
    total_amount NUMERIC(10,2),
    rating NUMERIC(2,1),
    review_text TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_customer_job_history_customer_id ON customer_job_history(customer_id);
CREATE INDEX idx_customer_job_history_service_request_id ON customer_job_history(service_request_id);

COMMENT ON TABLE customer_job_history IS 'Customer job history records';

-- ========================================
-- 5. NOTIFICATION & COMMUNICATION TABLES
-- ========================================

-- Notifications
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    title VARCHAR(255),
    body TEXT,
    type VARCHAR(50),
    data JSONB,
    read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(read);

COMMENT ON TABLE notifications IS 'In-app notifications';

-- Messages
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    receiver_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    message TEXT,
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    is_read BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_messages_request_id ON messages(request_id);
CREATE INDEX idx_messages_sender_id ON messages(sender_id);
CREATE INDEX idx_messages_receiver_id ON messages(receiver_id);

COMMENT ON TABLE messages IS 'Chat messages between users';

-- Shop Notifications
CREATE TABLE shop_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID REFERENCES shops(id) ON DELETE CASCADE,
    shop_owner_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    related_request_id UUID REFERENCES service_requests(id),
    notification_type VARCHAR(50),
    title VARCHAR(255),
    message TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE shop_notifications IS 'Shop-specific notifications';

-- ========================================
-- 6. BROADCAST & REQUEST ROUTING TABLES
-- ========================================

-- Request Broadcasts
CREATE TABLE request_broadcasts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES service_providers(id),
    shop_id UUID REFERENCES shops(id),
    mechanic_id UUID REFERENCES user_profiles(id),
    provider_type VARCHAR(20),
    distance_km NUMERIC(5,2),
    notification_sent_at TIMESTAMPTZ,
    viewed_at TIMESTAMPTZ,
    response_status VARCHAR(20) DEFAULT 'pending',
    responded_at TIMESTAMPTZ
);

CREATE INDEX idx_request_broadcasts_request_id ON request_broadcasts(request_id);
CREATE INDEX idx_request_broadcasts_provider_id ON request_broadcasts(provider_id);

COMMENT ON TABLE request_broadcasts IS 'Broadcast notifications to nearby providers';

-- Request Routing
CREATE TABLE request_routing (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE,
    eligible_mechanic_id UUID REFERENCES user_profiles(id),
    eligible_shop_id UUID REFERENCES shops(id),
    routing_type VARCHAR(20),
    is_notified BOOLEAN DEFAULT FALSE,
    distance_km NUMERIC(5,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE request_routing IS 'Request routing algorithm data';

-- ========================================
-- 7. REVIEW & RATING TABLES
-- ========================================

-- Reviews
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES service_providers(id),
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    response TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_reviews_request_id ON reviews(request_id);
CREATE INDEX idx_reviews_provider_id ON reviews(provider_id);

COMMENT ON TABLE reviews IS 'Customer reviews and ratings';

-- ========================================
-- 8. PROGRESS & DOCUMENTATION TABLES
-- ========================================

-- Progress Photos
CREATE TABLE progress_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE,
    mechanic_id UUID REFERENCES user_profiles(id),
    service_phase VARCHAR(30),
    image_url TEXT,
    description TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_progress_photos_service_request_id ON progress_photos(service_request_id);

COMMENT ON TABLE progress_photos IS 'Job progress documentation photos';

-- Service Phase Tracking
CREATE TABLE service_phase_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_request_id UUID UNIQUE REFERENCES service_requests(id) ON DELETE CASCADE,
    mechanic_id UUID REFERENCES user_profiles(id),
    current_phase VARCHAR(30),
    phase_started_at TIMESTAMPTZ,
    phase_history JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE service_phase_tracking IS 'Service phase progression tracking';

-- ========================================
-- 9. SECURITY & AUTHENTICATION TABLES
-- ========================================

-- Account Security Logs
CREATE TABLE account_security_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    action_type VARCHAR(50),
    ip_address INET,
    user_agent TEXT,
    success BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_account_security_logs_user_id ON account_security_logs(user_id);

COMMENT ON TABLE account_security_logs IS 'User security event logs';

-- Password Reset Tokens
CREATE TABLE password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT UNIQUE NOT NULL,
    expires_at TIMESTAMPTZ,
    used_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE password_reset_tokens IS 'Password reset tokens';

-- Email Verification Tokens
CREATE TABLE email_verification_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    old_email VARCHAR(255),
    new_email VARCHAR(255),
    token TEXT UNIQUE NOT NULL,
    token_type VARCHAR(20),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE email_verification_tokens IS 'Email verification tokens';

-- ========================================
-- 10. MECHANIC MANAGEMENT TABLES
-- ========================================

-- Mechanic Invitations
CREATE TABLE mechanic_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_owner_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    shop_id UUID REFERENCES shops(id) ON DELETE CASCADE,
    mechanic_user_id UUID REFERENCES auth.users(id),
    email VARCHAR(255),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    temporary_password TEXT,
    invitation_token TEXT UNIQUE,
    status VARCHAR(20) DEFAULT 'pending',
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE mechanic_invitations IS 'Shop owner mechanic invitations';

-- Shop Mechanics
CREATE TABLE shop_mechanics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID REFERENCES shops(id) ON DELETE CASCADE,
    mechanic_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    role VARCHAR(50),
    hourly_rate NUMERIC(10,2),
    is_active BOOLEAN DEFAULT TRUE,
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_shop_mechanics_shop_id ON shop_mechanics(shop_id);
CREATE INDEX idx_shop_mechanics_mechanic_id ON shop_mechanics(mechanic_id);

COMMENT ON TABLE shop_mechanics IS 'Shop-mechanic assignments';

-- Mechanic Availability Status
CREATE TABLE mechanic_availability_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mechanic_id UUID UNIQUE REFERENCES user_profiles(id) ON DELETE CASCADE,
    shop_id UUID REFERENCES shops(id),
    current_request_id UUID REFERENCES service_requests(id),
    current_status VARCHAR(20),
    location_latitude NUMERIC(10,8),
    location_longitude NUMERIC(11,8),
    is_accepting_requests BOOLEAN DEFAULT TRUE,
    last_updated TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE mechanic_availability_status IS 'Real-time mechanic availability';

-- ========================================
-- 11. VERIFICATION TABLES
-- ========================================

-- Document Verifications
CREATE TABLE document_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    verified_by UUID REFERENCES auth.users(id),
    document_type VARCHAR(50),
    document_url TEXT,
    verification_status VARCHAR(20) DEFAULT 'pending',
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE document_verifications IS 'Document verification records';

-- Business Permits
CREATE TABLE business_permits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID REFERENCES service_providers(id) ON DELETE CASCADE,
    verified_by UUID REFERENCES auth.users(id),
    business_permit_name VARCHAR(255),
    registered_address TEXT,
    receipt_no VARCHAR(100) UNIQUE,
    permit_document_url TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE business_permits IS 'Business permit records';

-- Talyer Owner Verifications
CREATE TABLE talyer_owner_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES user_profiles(id) ON DELETE CASCADE,
    reviewed_by UUID REFERENCES auth.users(id),
    business_name VARCHAR(255),
    business_permit_url TEXT,
    valid_id_url TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE talyer_owner_verifications IS 'Talyer owner verification records';

-- ========================================
-- 12. JOB COMPLETION TABLES
-- ========================================

-- Job Completion Codes
CREATE TABLE job_completion_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES user_profiles(id),
    used_by_provider_id UUID REFERENCES service_providers(id),
    completion_code TEXT UNIQUE NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    expires_at TIMESTAMPTZ,
    used_at TIMESTAMPTZ,
    verification_status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE job_completion_codes IS 'QR code job completion verification';

-- Service Completions
CREATE TABLE service_completions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE,
    mechanic_id UUID REFERENCES user_profiles(id),
    customer_id UUID REFERENCES user_profiles(id),
    completion_code TEXT UNIQUE,
    qr_code_data TEXT,
    is_scanned BOOLEAN DEFAULT FALSE,
    scanned_at TIMESTAMPTZ,
    verification_status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE service_completions IS 'Service completion records';

-- ========================================
-- 13. ADMIN & AUDIT TABLES
-- ========================================

-- Admin Activity Logs
CREATE TABLE admin_activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    action_type VARCHAR(50),
    target_type VARCHAR(50),
    target_id UUID,
    action_details JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE admin_activity_logs IS 'Admin action audit trail';

-- Audit Logs
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    role VARCHAR(50),
    action VARCHAR(100),
    table_name VARCHAR(100),
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_table_name ON audit_logs(table_name);

COMMENT ON TABLE audit_logs IS 'System-wide audit trail';

-- ========================================
-- 14. EMAIL & NOTIFICATION TEMPLATES
-- ========================================

-- Email Notifications
CREATE TABLE email_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    sender_user_id UUID REFERENCES auth.users(id),
    email_type VARCHAR(50),
    recipient_email VARCHAR(255),
    subject VARCHAR(255),
    body TEXT,
    delivery_status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE email_notifications IS 'Email notification records';

-- Notification Templates
CREATE TABLE notification_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category VARCHAR(50),
    priority VARCHAR(20),
    title_template TEXT,
    message_template TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE notification_templates IS 'Notification message templates';

-- ========================================
-- 15. UTILITY & CONFIGURATION TABLES
-- ========================================

-- App Settings
CREATE TABLE app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(100) UNIQUE NOT NULL,
    value TEXT,
    description TEXT,
    is_public BOOLEAN DEFAULT FALSE,
    category VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE app_settings IS 'Application configuration settings';

-- Distance Pricing Config
CREATE TABLE distance_pricing_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    base_rate_per_km NUMERIC(10,2),
    minimum_service_fee NUMERIC(10,2),
    maximum_service_fee NUMERIC(10,2),
    emergency_multiplier NUMERIC(5,2) DEFAULT 1.5,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE distance_pricing_config IS 'Dynamic pricing configuration';

-- ========================================
-- TRIGGERS & FUNCTIONS
-- ========================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to user_profiles
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Apply trigger to app_settings
CREATE TRIGGER update_app_settings_updated_at
    BEFORE UPDATE ON app_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ========================================
-- ENABLE ROW LEVEL SECURITY (RLS)
-- ========================================

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Example RLS Policies (customize based on your needs)

-- Users can view their own profile
CREATE POLICY "Users can view own profile"
    ON user_profiles FOR SELECT
    USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
    ON user_profiles FOR UPDATE
    USING (auth.uid() = id);

-- Customers can view their own service requests
CREATE POLICY "Customers can view own requests"
    ON service_requests FOR SELECT
    USING (auth.uid() = customer_id);

-- Mechanics can view assigned requests
CREATE POLICY "Mechanics can view assigned requests"
    ON service_requests FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM service_providers
            WHERE service_providers.user_id = auth.uid()
            AND service_providers.id = service_requests.provider_id
        )
    );

-- ========================================
-- SEED DATA (Optional)
-- ========================================

-- Insert default service categories
INSERT INTO service_categories (name, description, category_type, base_price, estimated_duration) VALUES
('Tire Repair', 'Flat tire repair and replacement', 'standard', 500.00, 30),
('Battery Jump Start', 'Battery jump start service', 'emergency', 300.00, 15),
('Oil Change', 'Engine oil change service', 'standard', 800.00, 45),
('Brake Repair', 'Brake pad replacement and repair', 'standard', 1500.00, 60),
('Engine Diagnostics', 'Full engine diagnostic check', 'specialized', 1200.00, 90),
('Towing Service', 'Vehicle towing service', 'emergency', 2000.00, 60);

-- Insert default app settings
INSERT INTO app_settings (key, value, description, category, is_public) VALUES
('platform_fee_percentage', '7', 'Platform commission percentage', 'financial', false),
('broadcast_radius_km', '15', 'Default broadcast radius in kilometers', 'service', true),
('service_request_timeout_minutes', '15', 'Timeout for unaccepted requests', 'service', false),
('max_active_requests_per_customer', '3', 'Maximum concurrent requests per customer', 'service', false);

-- Insert default pricing config
INSERT INTO distance_pricing_config (base_rate_per_km, minimum_service_fee, maximum_service_fee, emergency_multiplier, is_active) VALUES
(50.00, 200.00, 5000.00, 1.5, true);

-- ========================================
-- END OF SCHEMA
-- ========================================
