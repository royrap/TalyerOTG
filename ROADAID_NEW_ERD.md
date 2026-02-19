# 🗄️ RoadAid System - Enhanced Entity Relationship Diagram (ERD)

**Date Created:** January 19, 2026  
**System:** RoadAid - Comprehensive Roadside Assistance Platform  
**Database:** PostgreSQL (Supabase)  
**Version:** 2.0 - Enhanced Edition

---

## 📊 ERD Visual Representation

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                        AUTHENTICATION & USER MANAGEMENT                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

                                           ┌─────────────────────┐
                                           │     auth.users      │
                                           │     (Supabase)      │
                                           ├─────────────────────┤
                                           │ PK id: uuid         │
                                           │    email: text      │
                                           │    encrypted_pwd    │
                                           │    created_at       │
                                           └──────────┬──────────┘
                                                      │ 1:1
                              ┌────────────────────────┼────────────────────────┐
                              │                        │                        │
                              ▼                        ▼                        ▼
              ┌─────────────────────────┐  ┌─────────────────────────┐  ┌─────────────────────────┐
              │   account_security_logs │  │      user_profiles      │  │  password_reset_tokens  │
              ├─────────────────────────┤  ├─────────────────────────┤  ├─────────────────────────┤
              │ PK id: uuid             │  │ PK/FK id: uuid          │  │ PK id: uuid             │
              │ FK user_id: uuid        │  │    first_name: varchar  │  │ FK user_id: uuid        │
              │    action_type: text    │  │    last_name: varchar   │  │    token: text UNIQUE   │
              │    ip_address: inet     │  │    email: varchar       │  │    expires_at: timestz  │
              │    user_agent: text     │  │    phone_number: varchar│  │    is_active: boolean   │
              │    success: boolean     │  │    user_type: varchar   │  └─────────────────────────┘
              │    created_at: timestz  │  │    status: varchar      │
              └─────────────────────────┘  │    profile_image_url    │
                                           │    current_latitude     │
                                           │    current_longitude    │
                                           │ FK shop_id: uuid        │
                                           │    rating: numeric      │
                                           │    created_at           │
                                           │    updated_at           │
                                           └───────────┬─────────────┘
                                                       │
                    ┌──────────────────┬───────────────┼────────────────┬──────────────────┐
                    │                  │               │                │                  │
                    ▼                  ▼               ▼                ▼                  ▼

┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                            USER TYPE SPECIFIC ENTITIES                                   │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐
    │      vehicles       │  │ service_providers   │  │        shops        │  │    notifications    │
    ├─────────────────────┤  ├─────────────────────┤  ├─────────────────────┤  ├─────────────────────┤
    │ PK id: uuid         │  │ PK id: uuid         │  │ PK id: uuid         │  │ PK id: uuid         │
    │ FK user_id: uuid    │  │ FK user_id: uuid    │  │ FK owner_id: uuid   │  │ FK user_id: uuid    │
    │    brand_name       │  │ FK shop_id: uuid    │  │    shop_name        │  │    title: text      │
    │    model_name       │  │ FK talyer_owner_id  │  │    shop_address     │  │    body: text       │
    │    year: integer    │  │    company_name     │  │    shop_phone       │  │    type: text       │
    │    plate_number     │  │    rating: numeric  │  │    shop_email       │  │    data: jsonb      │
    │    vehicle_type     │  │    service_radius   │  │    latitude         │  │    read: boolean    │
    │    is_primary: bool │  │    is_verified      │  │    longitude        │  │    created_at       │
    └─────────────────────┘  │    is_available     │  │    service_radius   │  └─────────────────────┘
                             │    current_latitude │  │    business_hours   │
                             │    current_longitude│  │    current_status   │
                             │    status           │  │    rating           │
                             └──────────┬──────────┘  │    is_active        │
                                        │             └──────────┬──────────┘
                                        │                        │
                                        │     1:N                │ 1:N
                                        └────────────┬───────────┘
                                                     │
                                                     ▼

┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                           SHOP MANAGEMENT ENTITIES                                       │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

              ┌─────────────────────────┐                     ┌─────────────────────────┐
              │     shop_mechanics      │                     │      shop_services      │
              ├─────────────────────────┤                     ├─────────────────────────┤
              │ PK id: uuid             │                     │ PK id: uuid             │
              │ FK shop_id: uuid        │                     │ FK shop_id: uuid        │
              │ FK mechanic_id: uuid    │                     │ FK category_id: uuid    │
              │    role: varchar        │                     │    service_name: text   │
              │    hourly_rate: numeric │                     │    description: text    │
              │    is_active: boolean   │                     │    base_price: numeric  │
              │    is_available: boolean│                     │    custom_price: numeric│
              └─────────────────────────┘                     │    estimated_duration   │
                                                              │    is_active: boolean   │
              ┌─────────────────────────┐                     │    availability_status  │
              │  mechanic_invitations   │                     └──────────┬──────────────┘
              ├─────────────────────────┤                                │
              │ PK id: uuid             │                                │ N:1
              │ FK shop_owner_id: uuid  │                                ▼
              │ FK shop_id: uuid        │                     ┌─────────────────────────┐
              │ FK mechanic_user_id     │                     │  service_categories     │
              │    email: text          │                     ├─────────────────────────┤
              │    first_name: text     │                     │ PK id: uuid             │
              │    last_name: text      │                     │    name: varchar UNIQUE │
              │    temporary_password   │                     │    description: text    │
              │    invitation_token     │                     │    base_price: numeric  │
              │    status: text         │                     │    estimated_duration   │
              │    expires_at: timestz  │                     │    category_type: text  │
              └─────────────────────────┘                     │    is_active: boolean   │
                                                              └─────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                         SERVICE REQUEST CORE ENTITY                                      │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

                                    ┌───────────────────────────────────┐
                                    │        service_requests           │
                                    ├───────────────────────────────────┤
                                    │ PK id: uuid                       │
                                    │ FK customer_id: uuid              │◄──── user_profiles (customer)
                                    │ FK provider_id: uuid              │◄──── service_providers
                                    │ FK vehicle_id: uuid               │◄──── vehicles
                                    │ FK category_id: uuid              │◄──── service_categories
                                    │ FK shop_id: uuid                  │◄──── shops
                                    │ FK assigned_mechanic_id: uuid     │◄──── user_profiles (mechanic)
                                    │    title: varchar                 │
                                    │    description: text              │
                                    │    status: varchar                │
                                    │    pickup_latitude: numeric       │
                                    │    pickup_longitude: numeric      │
                                    │    pickup_address: text           │
                                    │    service_fee: numeric           │
                                    │    estimated_price: numeric       │
                                    │    final_price: numeric           │
                                    │    payment_status: varchar        │
                                    │    request_type: text             │
                                    │    is_broadcast_request: boolean  │
                                    │    broadcast_radius_km: numeric   │
                                    │    created_at: timestamptz        │
                                    │    updated_at: timestamptz        │
                                    │    completed_at: timestamptz      │
                                    └───────────────┬───────────────────┘
                                                    │
                 ┌──────────────────┬───────────────┼───────────────┬──────────────────┐
                 │                  │               │               │                  │
                 ▼                  ▼               ▼               ▼                  ▼

┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                       SERVICE REQUEST RELATED ENTITIES                                   │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
│ request_broadcasts  │ │   progress_photos   │ │      messages       │ │ job_completion_codes│ │ service_completions │
├─────────────────────┤ ├─────────────────────┤ ├─────────────────────┤ ├─────────────────────┤ ├─────────────────────┤
│ PK id: uuid         │ │ PK id: uuid         │ │ PK id: uuid         │ │ PK id: uuid         │ │ PK id: uuid         │
│ FK request_id: uuid │ │ FK service_req_id   │ │ FK request_id: uuid │ │ FK request_id: uuid │ │ FK request_id: uuid │
│ FK provider_id: uuid│ │ FK mechanic_id: uuid│ │ FK sender_id: uuid  │ │ FK customer_id: uuid│ │ FK mechanic_id: uuid│
│ FK shop_id: uuid    │ │    service_phase    │ │ FK receiver_id: uuid│ │ FK used_by_provider │ │ FK customer_id: uuid│
│ FK mechanic_id: uuid│ │    image_url: text  │ │    message: text    │ │    completion_code  │ │    completion_code  │
│    provider_type    │ │    description: text│ │    sent_at: timestz │ │    is_used: boolean │ │    qr_code_data     │
│    distance_km      │ │    timestamp:timestz│ │    is_read: boolean │ │    expires_at       │ │    is_scanned       │
│    notification_sent│ └─────────────────────┘ └─────────────────────┘ │    used_at          │ │    scanned_at       │
│    viewed_at        │                                                 │    verification_stat│ │    verification_stat│
│    response_status  │                                                 └─────────────────────┘ └─────────────────────┘
│    responded_at     │
└─────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                           FINANCIAL ENTITIES                                             │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────────────────────────────────────────┐
                    │                         invoices                            │
                    ├─────────────────────────────────────────────────────────────┤
                    │ PK id: uuid                                                 │
                    │ FK request_id: uuid                                         │◄──── service_requests
                    │ FK customer_id: uuid                                        │◄──── user_profiles
                    │ FK mechanic_id: uuid                                        │◄──── user_profiles
                    │ FK talyer_owner_id: uuid                                    │◄──── user_profiles
                    │ FK provider_id: uuid                                        │◄──── service_providers
                    │    invoice_number: text UNIQUE                              │
                    │    subtotal: numeric                                        │
                    │    platform_fee: numeric                                    │
                    │    total_amount: numeric                                    │
                    │    talyer_net_amount: numeric                               │
                    │    provider_net_amount: numeric                             │
                    │    status: text (generated/sent/paid/disputed)              │
                    │    selected_payment_method: text (cash/gcash/paymaya)       │
                    │    payment_details: jsonb                                   │
                    │    generated_at: timestamptz                                │
                    │    paid_at: timestamptz                                     │
                    └──────────────────────────────┬──────────────────────────────┘
                                                   │ 1:N
                                                   ▼
                    ┌─────────────────────────────────────────────────────────────┐
                    │                         payments                            │
                    ├─────────────────────────────────────────────────────────────┤
                    │ PK id: uuid                                                 │
                    │ FK request_id: uuid                                         │◄──── service_requests
                    │ FK customer_id: uuid                                        │◄──── user_profiles
                    │ FK provider_id: uuid                                        │◄──── service_providers
                    │ FK invoice_id: uuid                                         │◄──── invoices
                    │    amount: numeric                                          │
                    │    platform_fee: numeric                                    │
                    │    provider_amount: numeric                                 │
                    │    payment_method: varchar (cash/gcash/paymaya/card)        │
                    │    transaction_id: varchar                                  │
                    │    status: varchar (pending/completed/failed/refunded)      │
                    │    payment_gateway: varchar (paymongo)                      │
                    │    payment_verification_required: boolean                   │
                    │    verification_status: varchar                             │
                    │    processed_at: timestamptz                                │
                    │    created_at: timestamptz                                  │
                    └──────────────────────────────┬──────────────────────────────┘
                                                   │ 1:1
                    ┌──────────────────────────────┴──────────────────────────────┐
                    │                                                             │
                    ▼                                                             ▼
    ┌───────────────────────────────────┐             ┌───────────────────────────────────┐
    │       payment_releases            │             │   cash_payment_verifications      │
    ├───────────────────────────────────┤             ├───────────────────────────────────┤
    │ PK id: uuid                       │             │ PK id: uuid                       │
    │ FK payment_id: uuid               │             │ FK invoice_id: uuid               │
    │ FK request_id: uuid               │             │ FK payment_id: uuid               │
    │ FK provider_id: uuid              │             │ FK request_id: uuid               │
    │ FK customer_id: uuid              │             │ FK customer_id: uuid              │
    │ FK admin_id: uuid                 │             │ FK mechanic_id: uuid              │
    │    total_amount: numeric          │             │ FK verified_by: uuid              │
    │    platform_fee: numeric          │             │    cash_amount: numeric           │
    │    provider_amount: numeric       │             │    cash_photo_url: text           │
    │    release_status: varchar        │             │    receipt_photo_url: text        │
    │    release_method: varchar        │             │    verification_status: text      │
    │    approved_at: timestamptz       │             │    verified_at: timestamptz       │
    │    released_at: timestamptz       │             │    created_at: timestamptz        │
    │    created_at: timestamptz        │             └───────────────────────────────────┘
    └───────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                          JOB HISTORY ENTITIES                                            │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

    ┌───────────────────────────────────────────────┐     ┌───────────────────────────────────────────────┐
    │          mechanic_job_history                 │     │          customer_job_history                 │
    ├───────────────────────────────────────────────┤     ├───────────────────────────────────────────────┤
    │ PK id: uuid                                   │     │ PK id: uuid                                   │
    │ FK mechanic_id: uuid ──────────────────────────────►│ FK customer_id: uuid ◄────────────────────────│
    │ FK service_request_id: uuid ◄─────────► service_requests ◄─────────► FK service_request_id: uuid │
    │ FK customer_id: uuid ◄─────────────────────────────►│ FK mechanic_id: uuid ────────────────────────►│
    │ FK shop_id: uuid                              │     │ FK shop_id: uuid                              │
    │    job_title: text                            │     │    job_title: text                            │
    │    job_description: text                      │     │    job_description: text                      │
    │    job_status: text                           │     │    job_status: text                           │
    │    completed_at: timestamptz                  │     │    completed_at: timestamptz                  │
    │    total_amount: numeric                      │     │    total_amount: numeric                      │
    │    mechanic_earnings: numeric                 │     │    rating: numeric                            │
    │    shop_earnings: numeric                     │     │    review_text: text                          │
    │    platform_fee: numeric                      │     │    created_at: timestamptz                    │
    │    rating: numeric                            │     └───────────────────────────────────────────────┘
    │    review_text: text                          │
    │    created_at: timestamptz                    │
    └───────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                           REVIEWS & RATINGS                                              │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

                              ┌───────────────────────────────────────────────┐
                              │                   reviews                     │
                              ├───────────────────────────────────────────────┤
                              │ PK id: uuid                                   │
                              │ FK request_id: uuid ◄───── service_requests   │
                              │ FK customer_id: uuid ◄───── user_profiles     │
                              │ FK provider_id: uuid ◄───── service_providers │
                              │    rating: integer (1-5)                      │
                              │    comment: text                              │
                              │    response: text (provider response)         │
                              │    is_verified: boolean                       │
                              │    created_at: timestamptz                    │
                              │    updated_at: timestamptz                    │
                              └───────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                        VERIFICATION ENTITIES                                             │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────┐  ┌─────────────────────────────────────┐  ┌─────────────────────────────────────┐
│   talyer_owner_verifications        │  │     document_verifications          │  │        business_permits             │
├─────────────────────────────────────┤  ├─────────────────────────────────────┤  ├─────────────────────────────────────┤
│ PK id: uuid                         │  │ PK id: uuid                         │  │ PK id: uuid                         │
│ FK user_id: uuid UNIQUE             │  │ FK user_id: uuid                    │  │ FK provider_id: uuid                │
│ FK reviewed_by: uuid                │  │ FK verified_by: uuid                │  │ FK verified_by: uuid                │
│    business_name: varchar           │  │    document_type: text              │  │    business_permit_name: text       │
│    business_permit_url: text        │  │    document_url: text               │  │    registered_address: text         │
│    valid_id_url: text               │  │    verification_status: text        │  │    receipt_no: text UNIQUE          │
│    id_type: varchar                 │  │    verified_at: timestamptz         │  │    permit_document_url: text        │
│    permit_expiry_date: date         │  │    created_at: timestamptz          │  │    is_verified: boolean             │
│    id_expiry_date: date             │  └─────────────────────────────────────┘  │    verified_at: timestamptz         │
│    status: varchar                  │                                           └─────────────────────────────────────┘
│    admin_notes: text                │
│    verification_score: integer      │
│    reviewed_at: timestamptz         │
│    created_at: timestamptz          │
└─────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                         ADMIN & AUDIT ENTITIES                                           │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────┐     ┌───────────────────────────────────────────────┐
│          admin_activity_logs                  │     │               audit_logs                      │
├───────────────────────────────────────────────┤     ├───────────────────────────────────────────────┤
│ PK id: uuid                                   │     │ PK id: uuid                                   │
│ FK admin_id: uuid ◄───── auth.users           │     │ FK user_id: uuid ◄───── user_profiles        │
│    action_type: varchar                       │     │    role: varchar                              │
│    target_type: varchar                       │     │    action: text                               │
│    target_id: uuid                            │     │    table_name: varchar                        │
│    action_details: jsonb                      │     │    record_id: uuid                            │
│    ip_address: inet                           │     │    old_values: jsonb                          │
│    user_agent: text                           │     │    new_values: jsonb                          │
│    created_at: timestamptz                    │     │    created_at: timestamptz                    │
└───────────────────────────────────────────────┘     └───────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                       CONFIGURATION ENTITIES                                             │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────┐     ┌───────────────────────────────────────────────┐
│            app_settings                       │     │        distance_pricing_config                │
├───────────────────────────────────────────────┤     ├───────────────────────────────────────────────┤
│ PK id: uuid                                   │     │ PK id: uuid                                   │
│    key: varchar UNIQUE                        │     │    base_rate_per_km: numeric                  │
│    value: text                                │     │    minimum_service_fee: numeric               │
│    description: text                          │     │    maximum_service_fee: numeric               │
│    is_public: boolean                         │     │    emergency_multiplier: numeric              │
│    category: text                             │     │    is_active: boolean                         │
│    updated_at: timestamptz                    │     │    created_at: timestamptz                    │
└───────────────────────────────────────────────┘     └───────────────────────────────────────────────┘

┌───────────────────────────────────────────────┐
│        notification_templates                 │
├───────────────────────────────────────────────┤
│ PK id: uuid                                   │
│    category: text                             │
│    priority: text                             │
│    title_template: text                       │
│    message_template: text                     │
│    is_active: boolean                         │
│    created_at: timestamptz                    │
└───────────────────────────────────────────────┘

```

---

## 📊 Complete Relationship Matrix

### Primary Relationships

| Parent Entity | Child Entity | Relationship | Foreign Key |
|--------------|--------------|--------------|-------------|
| auth.users | user_profiles | 1:1 | user_profiles.id → auth.users.id |
| auth.users | account_security_logs | 1:N | account_security_logs.user_id → auth.users.id |
| auth.users | password_reset_tokens | 1:N | password_reset_tokens.user_id → auth.users.id |
| user_profiles | shops | 1:1 | shops.owner_id → user_profiles.id |
| user_profiles | vehicles | 1:N | vehicles.user_id → user_profiles.id |
| user_profiles | service_providers | 1:1 | service_providers.user_id → user_profiles.id |
| user_profiles | notifications | 1:N | notifications.user_id → user_profiles.id |
| shops | service_providers | 1:N | service_providers.shop_id → shops.id |
| shops | shop_services | 1:N | shop_services.shop_id → shops.id |
| shops | shop_mechanics | 1:N | shop_mechanics.shop_id → shops.id |
| service_categories | shop_services | 1:N | shop_services.category_id → service_categories.id |
| service_categories | service_requests | 1:N | service_requests.category_id → service_categories.id |

### Service Request Relationships

| Parent Entity | Child Entity | Relationship | Foreign Key |
|--------------|--------------|--------------|-------------|
| service_requests | invoices | 1:N | invoices.request_id → service_requests.id |
| service_requests | payments | 1:N | payments.request_id → service_requests.id |
| service_requests | request_broadcasts | 1:N | request_broadcasts.request_id → service_requests.id |
| service_requests | progress_photos | 1:N | progress_photos.service_request_id → service_requests.id |
| service_requests | messages | 1:N | messages.request_id → service_requests.id |
| service_requests | job_completion_codes | 1:1 | job_completion_codes.request_id → service_requests.id |
| service_requests | service_completions | 1:1 | service_completions.request_id → service_requests.id |
| service_requests | mechanic_job_history | 1:1 | mechanic_job_history.service_request_id → service_requests.id |
| service_requests | customer_job_history | 1:1 | customer_job_history.service_request_id → service_requests.id |
| service_requests | reviews | 1:N | reviews.request_id → service_requests.id |

### Financial Relationships

| Parent Entity | Child Entity | Relationship | Foreign Key |
|--------------|--------------|--------------|-------------|
| invoices | payments | 1:N | payments.invoice_id → invoices.id |
| payments | payment_releases | 1:1 | payment_releases.payment_id → payments.id |
| payments | cash_payment_verifications | 1:1 | cash_payment_verifications.payment_id → payments.id |
| invoices | cash_payment_verifications | 1:1 | cash_payment_verifications.invoice_id → invoices.id |

---

## 🔗 Cardinality Summary

| Relationship Type | Count | Examples |
|------------------|-------|----------|
| **1:1 (One-to-One)** | 12 | auth.users ↔ user_profiles, user_profiles ↔ service_providers |
| **1:N (One-to-Many)** | 45 | shops → shop_services, service_requests → progress_photos |
| **N:M (Many-to-Many)** | 3 | Via junction tables (shop_mechanics, provider_services) |

---

## 📈 Entity Statistics

### Core Entities
| Entity | Total Columns | Primary Keys | Foreign Keys | Indexes |
|--------|--------------|--------------|--------------|---------|
| user_profiles | 15 | 1 | 1 | 4 |
| shops | 14 | 1 | 1 | 3 |
| service_providers | 12 | 1 | 3 | 4 |
| service_requests | 22 | 1 | 6 | 8 |
| invoices | 17 | 1 | 5 | 5 |
| payments | 14 | 1 | 4 | 5 |

### Supporting Entities
| Entity | Total Columns | Primary Keys | Foreign Keys | Indexes |
|--------|--------------|--------------|--------------|---------|
| vehicles | 8 | 1 | 1 | 2 |
| service_categories | 7 | 1 | 0 | 2 |
| shop_services | 10 | 1 | 2 | 3 |
| reviews | 8 | 1 | 3 | 3 |
| notifications | 8 | 1 | 1 | 2 |

---

## 🎯 Key Constraints

### Primary Key Constraints (PK)
All tables use UUID as primary key: `gen_random_uuid()`

### Foreign Key Constraints (FK)
```sql
-- Example constraints
ALTER TABLE user_profiles 
  ADD CONSTRAINT user_profiles_id_fkey 
  FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE service_requests 
  ADD CONSTRAINT service_requests_customer_id_fkey 
  FOREIGN KEY (customer_id) REFERENCES user_profiles(id) ON DELETE CASCADE;

ALTER TABLE invoices 
  ADD CONSTRAINT invoices_request_id_fkey 
  FOREIGN KEY (request_id) REFERENCES service_requests(id) ON DELETE CASCADE;
```

### Unique Constraints
- `user_profiles.email` - UNIQUE
- `shops.owner_id` - UNIQUE (one shop per owner)
- `service_providers.user_id` - UNIQUE
- `invoices.invoice_number` - UNIQUE
- `service_categories.name` - UNIQUE

### Check Constraints
```sql
-- Status validations
CONSTRAINT valid_user_type CHECK (user_type IN ('customer', 'mechanic', 'talyer_owner', 'admin', 'super_admin'))
CONSTRAINT valid_request_status CHECK (status IN ('pending', 'accepted', 'en_route', 'arrived', 'in_progress', 'completed', 'cancelled'))
CONSTRAINT valid_payment_status CHECK (status IN ('pending', 'completed', 'failed', 'refunded'))
CONSTRAINT valid_rating CHECK (rating >= 1 AND rating <= 5)
```

---

## 🔐 Row Level Security (RLS) Summary

| Table | RLS Enabled | Policy Types |
|-------|-------------|--------------|
| user_profiles | ✅ | SELECT, UPDATE, INSERT |
| service_requests | ✅ | SELECT, UPDATE, INSERT |
| payments | ✅ | SELECT, UPDATE |
| invoices | ✅ | SELECT, UPDATE |
| notifications | ✅ | SELECT, UPDATE |
| shops | ✅ | SELECT, UPDATE, INSERT |

---

## 📊 Data Type Standards

| Data Type | Usage | Examples |
|-----------|-------|----------|
| `uuid` | All primary keys, foreign keys | id, user_id, request_id |
| `varchar` | Short text fields | name, status, type |
| `text` | Long text fields | description, address, notes |
| `numeric` | Money, coordinates | amount, latitude, longitude |
| `integer` | Counts, ratings | rating, year, duration |
| `boolean` | Flags | is_active, is_verified |
| `timestamptz` | All timestamps | created_at, updated_at |
| `jsonb` | Flexible data | business_hours, payment_details |
| `inet` | IP addresses | ip_address |

---

**Legend:**
- **PK** = Primary Key
- **FK** = Foreign Key
- **UNIQUE** = Unique Constraint
- **◄────** = Foreign Key Reference Direction
- **1:1** = One-to-One
- **1:N** = One-to-Many
- **N:M** = Many-to-Many

---

**Document Version:** 2.0  
**Last Updated:** January 19, 2026  
**Author:** System Documentation
