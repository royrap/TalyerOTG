-- ============================================================================
-- COMPLETE ROADAID DATABASE SCHEMA
-- Includes all system tables and super admin tables
-- ============================================================================

-- ============================================================================
-- CORE USER MANAGEMENT TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    display_name TEXT,
    phone_number TEXT,
    address TEXT,
    user_type TEXT NOT NULL CHECK (user_type IN ('customer', 'mechanic', 'talyer_owner', 'super_admin')),
    profile_image_url TEXT,
    is_active BOOLEAN DEFAULT true,
    location GEOGRAPHY(POINT, 4326),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_online BOOLEAN DEFAULT false,
    fcm_token TEXT,
    notification_enabled BOOLEAN DEFAULT true,
    email_verified BOOLEAN DEFAULT false,
    phone_verified BOOLEAN DEFAULT false
);

-- ============================================================================
-- SHOP & MECHANIC MANAGEMENT TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.shops (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    shop_name TEXT NOT NULL,
    shop_address TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    email TEXT,
    description TEXT,
    shop_image_url TEXT,
    location GEOGRAPHY(POINT, 4326),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    rating DECIMAL(3,2) DEFAULT 0.00,
    total_reviews INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    business_hours JSONB,
    services_offered TEXT[]
);

CREATE TABLE IF NOT EXISTS public.mechanics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    shop_id UUID REFERENCES public.shops(id) ON DELETE SET NULL,
    specializations TEXT[],
    years_experience INTEGER,
    is_available BOOLEAN DEFAULT true,
    current_location GEOGRAPHY(POINT, 4326),
    current_latitude DOUBLE PRECISION,
    current_longitude DOUBLE PRECISION,
    rating DECIMAL(3,2) DEFAULT 0.00,
    total_jobs INTEGER DEFAULT 0,
    total_reviews INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    license_number TEXT,
    is_verified BOOLEAN DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.shop_mechanics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    mechanic_id UUID NOT NULL REFERENCES public.mechanics(id) ON DELETE CASCADE,
    role TEXT DEFAULT 'mechanic',
    joined_date TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(shop_id, mechanic_id)
);

CREATE TABLE IF NOT EXISTS public.shop_services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    service_name TEXT NOT NULL,
    description TEXT,
    base_price DECIMAL(10,2),
    estimated_duration INTEGER,
    is_available BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    category TEXT,
    image_url TEXT
);

-- ============================================================================
-- SERVICE REQUEST & TRACKING TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.service_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    mechanic_id UUID REFERENCES public.mechanics(id) ON DELETE SET NULL,
    shop_id UUID REFERENCES public.shops(id) ON DELETE SET NULL,
    service_type TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending', 'accepted', 'mechanic_assigned', 'in_progress', 
        'completed', 'cancelled', 'rejected', 'dispatched', 'arrived',
        'diagnosing', 'repairing', 'waiting_payment', 'paid'
    )),
    location GEOGRAPHY(POINT, 4326),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    address TEXT,
    vehicle_details JSONB,
    estimated_cost DECIMAL(10,2),
    actual_cost DECIMAL(10,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'emergency')),
    photos TEXT[],
    customer_notes TEXT,
    mechanic_notes TEXT,
    assigned_at TIMESTAMPTZ,
    accepted_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    arrival_time TIMESTAMPTZ,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT,
    payment_method TEXT,
    payment_status TEXT DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid', 'refunded')),
    is_emergency BOOLEAN DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.service_request_status_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    status TEXT NOT NULL,
    changed_by UUID REFERENCES public.user_profiles(id),
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    notes TEXT,
    metadata JSONB
);

CREATE TABLE IF NOT EXISTS public.request_broadcasts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    broadcast_radius INTEGER NOT NULL DEFAULT 10000,
    mechanics_notified INTEGER DEFAULT 0,
    mechanics_responded INTEGER DEFAULT 0,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'accepted', 'expired', 'cancelled')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    accepted_by UUID REFERENCES public.mechanics(id),
    accepted_at TIMESTAMPTZ
);

-- ============================================================================
-- VEHICLE MANAGEMENT TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    make TEXT NOT NULL,
    model TEXT NOT NULL,
    year INTEGER NOT NULL,
    color TEXT,
    license_plate TEXT,
    vin TEXT,
    vehicle_type TEXT,
    notes TEXT,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- PAYMENT & INVOICE TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.user_profiles(id),
    mechanic_id UUID REFERENCES public.mechanics(id),
    shop_id UUID REFERENCES public.shops(id),
    invoice_number TEXT UNIQUE NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    total_amount DECIMAL(10,2) NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('draft', 'pending', 'paid', 'cancelled', 'refunded')),
    payment_method TEXT,
    payment_status TEXT DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'partial', 'paid', 'refunded')),
    paid_amount DECIMAL(10,2) DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    paid_at TIMESTAMPTZ,
    due_date TIMESTAMPTZ,
    items JSONB,
    labor_cost DECIMAL(10,2) DEFAULT 0,
    parts_cost DECIMAL(10,2) DEFAULT 0,
    service_fee DECIMAL(10,2) DEFAULT 0,
    payment_intent_id TEXT,
    payment_source_id TEXT,
    payment_link_url TEXT,
    qr_code_url TEXT,
    payment_completed BOOLEAN DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
    service_request_id UUID REFERENCES public.service_requests(id),
    customer_id UUID NOT NULL REFERENCES public.user_profiles(id),
    mechanic_id UUID REFERENCES public.mechanics(id),
    amount DECIMAL(10,2) NOT NULL,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'gcash', 'paymaya', 'card', 'bank_transfer', 'paymongo_qr')),
    payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'processing', 'completed', 'failed', 'refunded', 'cancelled')),
    transaction_id TEXT,
    payment_intent_id TEXT,
    payment_source_id TEXT,
    reference_number TEXT,
    payment_proof_url TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    failure_reason TEXT,
    metadata JSONB
);

CREATE TABLE IF NOT EXISTS public.paymongo_webhook_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id TEXT UNIQUE NOT NULL,
    event_type TEXT NOT NULL,
    resource_type TEXT,
    resource_id TEXT,
    data JSONB NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processed', 'failed')),
    processed_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.cash_payment_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payment_id UUID NOT NULL REFERENCES public.payments(id) ON DELETE CASCADE,
    invoice_id UUID NOT NULL REFERENCES public.invoices(id),
    service_request_id UUID NOT NULL REFERENCES public.service_requests(id),
    customer_id UUID NOT NULL REFERENCES public.user_profiles(id),
    mechanic_id UUID NOT NULL REFERENCES public.mechanics(id),
    amount DECIMAL(10,2) NOT NULL,
    photo_url TEXT NOT NULL,
    photo_taken_by TEXT NOT NULL CHECK (photo_taken_by IN ('customer', 'mechanic')),
    verified_by UUID REFERENCES public.user_profiles(id),
    verification_status TEXT DEFAULT 'pending' CHECK (verification_status IN ('pending', 'verified', 'rejected')),
    verification_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    verified_at TIMESTAMPTZ
);

-- ============================================================================
-- EARNINGS & FINANCIAL TRACKING TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.earnings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mechanic_id UUID NOT NULL REFERENCES public.mechanics(id) ON DELETE CASCADE,
    shop_id UUID REFERENCES public.shops(id) ON DELETE SET NULL,
    service_request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    invoice_id UUID REFERENCES public.invoices(id) ON DELETE SET NULL,
    gross_amount DECIMAL(10,2) NOT NULL,
    platform_fee DECIMAL(10,2) DEFAULT 0,
    shop_share DECIMAL(10,2) DEFAULT 0,
    net_amount DECIMAL(10,2) NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'cancelled')),
    payout_date TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- MESSAGING & COMMUNICATION TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'location', 'system')),
    attachment_url TEXT,
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- NOTIFICATION TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    notification_type TEXT NOT NULL,
    data JSONB,
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    action_url TEXT,
    image_url TEXT
);

CREATE TABLE IF NOT EXISTS public.notification_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    template_name TEXT UNIQUE NOT NULL,
    title_template TEXT NOT NULL,
    body_template TEXT NOT NULL,
    notification_type TEXT NOT NULL,
    priority TEXT DEFAULT 'normal',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.user_notification_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    notification_type TEXT NOT NULL,
    push_enabled BOOLEAN DEFAULT true,
    email_enabled BOOLEAN DEFAULT true,
    sms_enabled BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, notification_type)
);

CREATE TABLE IF NOT EXISTS public.notification_delivery_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    notification_id UUID REFERENCES public.notifications(id) ON DELETE SET NULL,
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    delivery_method TEXT NOT NULL CHECK (delivery_method IN ('push', 'email', 'sms')),
    status TEXT NOT NULL CHECK (status IN ('pending', 'sent', 'delivered', 'failed', 'bounced')),
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    delivered_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.do_not_disturb_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    days_of_week INTEGER[] DEFAULT ARRAY[1,2,3,4,5,6,7],
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

CREATE TABLE IF NOT EXISTS public.email_notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    subject TEXT NOT NULL,
    body TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed')),
    error_message TEXT,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    email_type TEXT,
    metadata JSONB
);

-- ============================================================================
-- REVIEW & RATING TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    mechanic_id UUID REFERENCES public.mechanics(id) ON DELETE CASCADE,
    shop_id UUID REFERENCES public.shops(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT,
    service_quality_rating INTEGER CHECK (service_quality_rating >= 1 AND service_quality_rating <= 5),
    professionalism_rating INTEGER CHECK (professionalism_rating >= 1 AND professionalism_rating <= 5),
    timeliness_rating INTEGER CHECK (timeliness_rating >= 1 AND timeliness_rating <= 5),
    value_rating INTEGER CHECK (value_rating >= 1 AND value_rating <= 5),
    would_recommend BOOLEAN,
    photos TEXT[],
    is_verified BOOLEAN DEFAULT false,
    is_visible BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    response_text TEXT,
    response_by UUID REFERENCES public.user_profiles(id),
    response_at TIMESTAMPTZ
);

-- ============================================================================
-- PROGRESS TRACKING & PHOTOS TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.progress_photos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    mechanic_id UUID NOT NULL REFERENCES public.mechanics(id) ON DELETE CASCADE,
    photo_url TEXT NOT NULL,
    description TEXT,
    phase TEXT NOT NULL CHECK (phase IN ('diagnosis', 'before_repair', 'during_repair', 'after_repair', 'completed')),
    sequence_number INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB
);

CREATE TABLE IF NOT EXISTS public.service_phase_tracking (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    phase TEXT NOT NULL,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    notes TEXT,
    photos TEXT[],
    created_by UUID REFERENCES public.user_profiles(id)
);

-- ============================================================================
-- HISTORY & AUDIT TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.mechanic_job_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mechanic_id UUID NOT NULL REFERENCES public.mechanics(id) ON DELETE CASCADE,
    service_request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.user_profiles(id),
    service_type TEXT NOT NULL,
    status TEXT NOT NULL,
    completed_at TIMESTAMPTZ,
    earnings DECIMAL(10,2),
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.customer_job_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    service_request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    mechanic_id UUID REFERENCES public.mechanics(id),
    service_type TEXT NOT NULL,
    status TEXT NOT NULL,
    completed_at TIMESTAMPTZ,
    total_cost DECIMAL(10,2),
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    table_name TEXT,
    record_id UUID,
    old_data JSONB,
    new_data JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    severity TEXT DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'error', 'critical')),
    metadata JSONB
);

CREATE TABLE IF NOT EXISTS public.account_security_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    ip_address INET,
    user_agent TEXT,
    status TEXT NOT NULL,
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- DOCUMENT VERIFICATION TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.document_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    document_type TEXT NOT NULL CHECK (document_type IN ('drivers_license', 'national_id', 'business_permit', 'professional_license')),
    document_number TEXT,
    front_image_url TEXT NOT NULL,
    back_image_url TEXT,
    selfie_image_url TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'expired')),
    verified_by UUID REFERENCES public.user_profiles(id),
    verified_at TIMESTAMPTZ,
    rejection_reason TEXT,
    expiry_date DATE,
    extracted_data JSONB,
    ai_confidence_score DECIMAL(5,4),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.business_permits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    owner_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    permit_number TEXT,
    business_name TEXT NOT NULL,
    permit_image_url TEXT NOT NULL,
    issue_date DATE,
    expiry_date DATE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'verified', 'rejected', 'expired')),
    verified_by UUID REFERENCES public.user_profiles(id),
    verified_at TIMESTAMPTZ,
    rejection_reason TEXT,
    extracted_data JSONB,
    ai_confidence_score DECIMAL(5,4),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- SYSTEM & CONFIGURATION TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.service_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    icon_url TEXT,
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.system_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    setting_key TEXT UNIQUE NOT NULL,
    setting_value JSONB NOT NULL,
    description TEXT,
    category TEXT,
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.app_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
    version TEXT NOT NULL,
    build_number INTEGER NOT NULL,
    is_required BOOLEAN DEFAULT false,
    release_notes TEXT,
    download_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(platform, version)
);

-- ============================================================================
-- SUPER ADMIN TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.admin_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('super_admin', 'admin', 'moderator', 'support')),
    permissions JSONB,
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES public.user_profiles(id)
);

CREATE TABLE IF NOT EXISTS public.admin_activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_id UUID NOT NULL REFERENCES public.admin_users(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    resource_type TEXT,
    resource_id UUID,
    details JSONB,
    ip_address INET,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.platform_statistics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    date DATE UNIQUE NOT NULL,
    total_users INTEGER DEFAULT 0,
    active_users INTEGER DEFAULT 0,
    new_users INTEGER DEFAULT 0,
    total_service_requests INTEGER DEFAULT 0,
    completed_requests INTEGER DEFAULT 0,
    cancelled_requests INTEGER DEFAULT 0,
    total_revenue DECIMAL(12,2) DEFAULT 0,
    platform_fees DECIMAL(12,2) DEFAULT 0,
    average_rating DECIMAL(3,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.reported_issues (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    reported_user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    service_request_id UUID REFERENCES public.service_requests(id) ON DELETE CASCADE,
    issue_type TEXT NOT NULL,
    description TEXT NOT NULL,
    evidence_urls TEXT[],
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'investigating', 'resolved', 'dismissed')),
    assigned_to UUID REFERENCES public.admin_users(id),
    resolution_notes TEXT,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.platform_announcements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    announcement_type TEXT NOT NULL CHECK (announcement_type IN ('maintenance', 'update', 'promotion', 'alert', 'general')),
    target_audience TEXT[] DEFAULT ARRAY['all'],
    is_active BOOLEAN DEFAULT true,
    priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    starts_at TIMESTAMPTZ DEFAULT NOW(),
    ends_at TIMESTAMPTZ,
    created_by UUID REFERENCES public.admin_users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- ============================================================================

-- User Profile Indexes
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON public.user_profiles(email);
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_type ON public.user_profiles(user_type);
CREATE INDEX IF NOT EXISTS idx_user_profiles_location ON public.user_profiles USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_user_profiles_is_active ON public.user_profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_user_profiles_is_online ON public.user_profiles(is_online);

-- Shop Indexes
CREATE INDEX IF NOT EXISTS idx_shops_owner_id ON public.shops(owner_id);
CREATE INDEX IF NOT EXISTS idx_shops_location ON public.shops USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_shops_is_active ON public.shops(is_active);
CREATE INDEX IF NOT EXISTS idx_shops_is_verified ON public.shops(is_verified);

-- Mechanic Indexes
CREATE INDEX IF NOT EXISTS idx_mechanics_user_id ON public.mechanics(user_id);
CREATE INDEX IF NOT EXISTS idx_mechanics_shop_id ON public.mechanics(shop_id);
CREATE INDEX IF NOT EXISTS idx_mechanics_is_available ON public.mechanics(is_available);
CREATE INDEX IF NOT EXISTS idx_mechanics_current_location ON public.mechanics USING GIST(current_location);

-- Service Request Indexes
CREATE INDEX IF NOT EXISTS idx_service_requests_customer_id ON public.service_requests(customer_id);
CREATE INDEX IF NOT EXISTS idx_service_requests_mechanic_id ON public.service_requests(mechanic_id);
CREATE INDEX IF NOT EXISTS idx_service_requests_shop_id ON public.service_requests(shop_id);
CREATE INDEX IF NOT EXISTS idx_service_requests_status ON public.service_requests(status);
CREATE INDEX IF NOT EXISTS idx_service_requests_created_at ON public.service_requests(created_at);
CREATE INDEX IF NOT EXISTS idx_service_requests_location ON public.service_requests USING GIST(location);

-- Invoice Indexes
CREATE INDEX IF NOT EXISTS idx_invoices_customer_id ON public.invoices(customer_id);
CREATE INDEX IF NOT EXISTS idx_invoices_mechanic_id ON public.invoices(mechanic_id);
CREATE INDEX IF NOT EXISTS idx_invoices_service_request_id ON public.invoices(service_request_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON public.invoices(status);
CREATE INDEX IF NOT EXISTS idx_invoices_payment_status ON public.invoices(payment_status);
CREATE INDEX IF NOT EXISTS idx_invoices_created_at ON public.invoices(created_at);

-- Payment Indexes
CREATE INDEX IF NOT EXISTS idx_payments_invoice_id ON public.payments(invoice_id);
CREATE INDEX IF NOT EXISTS idx_payments_customer_id ON public.payments(customer_id);
CREATE INDEX IF NOT EXISTS idx_payments_payment_status ON public.payments(payment_status);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON public.payments(created_at);

-- Notification Indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at);

-- Message Indexes
CREATE INDEX IF NOT EXISTS idx_messages_service_request_id ON public.messages(service_request_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_id ON public.messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at);

-- Review Indexes
CREATE INDEX IF NOT EXISTS idx_reviews_service_request_id ON public.reviews(service_request_id);
CREATE INDEX IF NOT EXISTS idx_reviews_customer_id ON public.reviews(customer_id);
CREATE INDEX IF NOT EXISTS idx_reviews_mechanic_id ON public.reviews(mechanic_id);
CREATE INDEX IF NOT EXISTS idx_reviews_shop_id ON public.reviews(shop_id);
CREATE INDEX IF NOT EXISTS idx_reviews_created_at ON public.reviews(created_at);

-- Audit Log Indexes
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_table_name ON public.audit_logs(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mechanics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_mechanics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.earnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.progress_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mechanic_job_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_job_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_permits ENABLE ROW LEVEL SECURITY;

-- User Profile Policies
CREATE POLICY "Users can view their own profile" ON public.user_profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON public.user_profiles
    FOR UPDATE USING (auth.uid() = id);

-- Service Request Policies
CREATE POLICY "Customers can view their own service requests" ON public.service_requests
    FOR SELECT USING (auth.uid() = customer_id);

CREATE POLICY "Mechanics can view assigned service requests" ON public.service_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.mechanics 
            WHERE user_id = auth.uid() AND id = service_requests.mechanic_id
        )
    );

-- Invoice Policies
CREATE POLICY "Customers can view their own invoices" ON public.invoices
    FOR SELECT USING (auth.uid() = customer_id);

CREATE POLICY "Mechanics can view their own invoices" ON public.invoices
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.mechanics 
            WHERE user_id = auth.uid() AND id = invoices.mechanic_id
        )
    );

-- Notification Policies
CREATE POLICY "Users can view their own notifications" ON public.notifications
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications" ON public.notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- Message Policies
CREATE POLICY "Users can view messages they sent or received" ON public.messages
    FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to relevant tables
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_shops_updated_at BEFORE UPDATE ON public.shops
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_mechanics_updated_at BEFORE UPDATE ON public.mechanics
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_service_requests_updated_at BEFORE UPDATE ON public.service_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_invoices_updated_at BEFORE UPDATE ON public.invoices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON public.payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- SUMMARY OF ALL TABLES IN THIS SCHEMA
-- ============================================================================
-- 
-- TOTAL TABLES: 57
--
-- Core User Management:
-- 1. user_profiles
-- 2. admin_users
-- 3. admin_activity_logs
--
-- Shop & Mechanic Management:
-- 4. shops
-- 5. mechanics
-- 6. shop_mechanics
-- 7. shop_services
--
-- Service Request & Tracking:
-- 8. service_requests
-- 9. service_request_status_log
-- 10. request_broadcasts
-- 11. service_categories
--
-- Vehicle Management:
-- 12. vehicles
--
-- Payment & Invoice:
-- 13. invoices
-- 14. payments
-- 15. paymongo_webhook_events
-- 16. cash_payment_verifications
-- 17. earnings
--
-- Messaging & Communication:
-- 18. messages
--
-- Notifications:
-- 19. notifications
-- 20. notification_templates
-- 21. user_notification_preferences
-- 22. notification_delivery_log
-- 23. do_not_disturb_settings
-- 24. email_notifications
--
-- Reviews & Ratings:
-- 25. reviews
--
-- Progress Tracking:
-- 26. progress_photos
-- 27. service_phase_tracking
--
-- History & Audit:
-- 28. mechanic_job_history
-- 29. customer_job_history
-- 30. audit_logs
-- 31. account_security_logs
--
-- Document Verification:
-- 32. document_verifications
-- 33. business_permits
--
-- System & Configuration:
-- 34. system_settings
-- 35. app_versions
--
-- Platform Administration:
-- 36. platform_statistics
-- 37. reported_issues
-- 38. platform_announcements
--
-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
