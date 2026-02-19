# 🗂️ ROADAID SYSTEM - ENTITY RELATIONSHIP DIAGRAM (ERD)

## 📋 Database Tables Ginamit sa Sistema

**Total Tables: 46 Active Tables**

---

## 🎯 CORE ENTITIES (Main Tables)

### 1. **user_profiles** (Central User Table)
```
┌─────────────────────────────────────┐
│         USER_PROFILES               │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│     email (TEXT) UNIQUE             │
│     display_name (TEXT)             │
│     phone_number (TEXT)             │
│     address (TEXT)                  │
│     user_type (TEXT)                │ ← customer/mechanic/talyer_owner/super_admin
│     profile_image_url (TEXT)        │
│     is_active (BOOLEAN)             │
│     location (GEOGRAPHY)            │
│     latitude (DOUBLE PRECISION)     │
│     longitude (DOUBLE PRECISION)    │
│     is_online (BOOLEAN)             │
│     fcm_token (TEXT)                │
│     notification_enabled (BOOLEAN)  │
│     created_at (TIMESTAMPTZ)        │
│     updated_at (TIMESTAMPTZ)        │
└─────────────────────────────────────┘
```

**Relationships:**
- ONE user → MANY shops (as owner)
- ONE user → ONE mechanic profile
- ONE user → MANY service_requests (as customer)
- ONE user → MANY vehicles
- ONE user → MANY notifications
- ONE user → MANY messages

---

### 2. **shops** (Auto Repair Shops)
```
┌─────────────────────────────────────┐
│            SHOPS                    │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  owner_id → user_profiles(id)    │
│     shop_name (TEXT)                │
│     shop_address (TEXT)             │
│     phone_number (TEXT)             │
│     email (TEXT)                    │
│     description (TEXT)              │
│     shop_image_url (TEXT)           │
│     latitude (DOUBLE PRECISION)     │
│     longitude (DOUBLE PRECISION)    │
│     is_active (BOOLEAN)             │
│     is_verified (BOOLEAN)           │
│     rating (DECIMAL)                │
│     total_reviews (INTEGER)         │
│     total_jobs (INTEGER)            │
│     business_hours (JSONB)          │
│     services_offered (TEXT[])       │
│     created_at (TIMESTAMPTZ)        │
└─────────────────────────────────────┘
```

**Relationships:**
- MANY shops → ONE user (owner)
- ONE shop → MANY mechanics
- ONE shop → MANY shop_services
- ONE shop → MANY service_requests
- ONE shop → MANY reviews

---

### 3. **mechanics** (Individual Mechanics)
```
┌─────────────────────────────────────┐
│           MECHANICS                 │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  user_id → user_profiles(id)     │ UNIQUE
│ FK  shop_id → shops(id)             │
│     specializations (TEXT[])        │
│     years_experience (INTEGER)      │
│     is_available (BOOLEAN)          │
│     current_latitude (DOUBLE)       │
│     current_longitude (DOUBLE)      │
│     rating (DECIMAL)                │
│     total_jobs (INTEGER)            │
│     total_reviews (INTEGER)         │
│     total_earnings (DECIMAL)        │
│     license_number (TEXT)           │
│     is_verified (BOOLEAN)           │
│     is_independent (BOOLEAN)        │
│     created_at (TIMESTAMPTZ)        │
└─────────────────────────────────────┘
```

**Relationships:**
- ONE mechanic → ONE user
- MANY mechanics → ONE shop
- ONE mechanic → MANY service_requests
- ONE mechanic → MANY shop_mechanics (if works for multiple shops)

---

### 4. **shop_mechanics** (Bridge Table)
```
┌─────────────────────────────────────┐
│        SHOP_MECHANICS               │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  shop_id → shops(id)             │
│ FK  mechanic_id → mechanics(id)     │
│     role (TEXT)                     │
│     joined_date (TIMESTAMPTZ)       │
│     is_active (BOOLEAN)             │
│     created_at (TIMESTAMPTZ)        │
└─────────────────────────────────────┘
```

**Relationships:**
- MANY-TO-MANY relationship between shops and mechanics

---

### 5. **vehicles** (Customer Vehicles)
```
┌─────────────────────────────────────┐
│           VEHICLES                  │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  customer_id → user_profiles(id) │
│     make (TEXT)                     │
│     model (TEXT)                    │
│     year (INTEGER)                  │
│     color (TEXT)                    │
│     license_plate (TEXT)            │
│     vin (TEXT)                      │
│     vehicle_type (TEXT)             │
│     is_default (BOOLEAN)            │
│     created_at (TIMESTAMPTZ)        │
└─────────────────────────────────────┘
```

**Relationships:**
- MANY vehicles → ONE customer (user_profiles)
- ONE vehicle → MANY service_requests

---

### 6. **service_requests** (Main Transaction Table)
```
┌─────────────────────────────────────┐
│       SERVICE_REQUESTS              │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  customer_id → user_profiles(id) │
│ FK  mechanic_id → mechanics(id)     │
│ FK  shop_id → shops(id)             │
│ FK  vehicle_id → vehicles(id)       │
│     service_type (TEXT)             │
│     description (TEXT)              │
│     status (TEXT)                   │ ← pending/accepted/in_progress/completed
│     latitude (DOUBLE PRECISION)     │
│     longitude (DOUBLE PRECISION)    │
│     address (TEXT)                  │
│     vehicle_details (JSONB)         │
│     estimated_cost (DECIMAL)        │
│     actual_cost (DECIMAL)           │
│     priority (TEXT)                 │
│     photos (TEXT[])                 │
│     customer_notes (TEXT)           │
│     mechanic_notes (TEXT)           │
│     payment_status (TEXT)           │
│     is_emergency (BOOLEAN)          │
│     qr_code (TEXT)                  │
│     qr_code_expires_at (TIMESTAMPTZ)│
│     created_at (TIMESTAMPTZ)        │
│     completed_at (TIMESTAMPTZ)      │
└─────────────────────────────────────┘
```

**Relationships:**
- MANY requests → ONE customer
- MANY requests → ONE mechanic
- MANY requests → ONE shop
- MANY requests → ONE vehicle
- ONE request → MANY status_logs
- ONE request → ONE invoice
- ONE request → MANY messages
- ONE request → MANY progress_photos

---

### 7. **invoices** (Payment Invoices)
```
┌─────────────────────────────────────┐
│           INVOICES                  │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  service_request_id              │
│ FK  customer_id → user_profiles(id) │
│ FK  mechanic_id → mechanics(id)     │
│ FK  shop_id → shops(id)             │
│     invoice_number (TEXT) UNIQUE    │
│     subtotal (DECIMAL)              │
│     service_fee (DECIMAL)           │
│     discount (DECIMAL)              │
│     tax (DECIMAL)                   │
│     total_amount (DECIMAL)          │
│     status (TEXT)                   │
│     payment_status (TEXT)           │
│     due_date (TIMESTAMPTZ)          │
│     paid_at (TIMESTAMPTZ)           │
│     line_items (JSONB)              │
│     created_at (TIMESTAMPTZ)        │
└─────────────────────────────────────┘
```

**Relationships:**
- ONE invoice → ONE service_request
- ONE invoice → MANY payments

---

### 8. **payments** (Payment Transactions)
```
┌─────────────────────────────────────┐
│           PAYMENTS                  │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  invoice_id → invoices(id)       │
│ FK  customer_id → user_profiles(id) │
│     payment_method (TEXT)           │
│     payment_status (TEXT)           │
│     amount (DECIMAL)                │
│     transaction_id (TEXT)           │
│     paymongo_payment_id (TEXT)      │
│     paymongo_checkout_url (TEXT)    │
│     payment_intent_id (TEXT)        │
│     paid_at (TIMESTAMPTZ)           │
│     created_at (TIMESTAMPTZ)        │
└─────────────────────────────────────┘
```

**Relationships:**
- MANY payments → ONE invoice
- MANY payments → ONE customer

---

## 🔗 SUPPORT TABLES

### 9. **shop_services** (Shop Service Offerings)
```
┌─────────────────────────────────────┐
│        SHOP_SERVICES                │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  shop_id → shops(id)             │
│     service_name (TEXT)             │
│     description (TEXT)              │
│     base_price (DECIMAL)            │
│     estimated_duration (INTEGER)    │
│     is_available (BOOLEAN)          │
│     category (TEXT)                 │
│     created_at (TIMESTAMPTZ)        │
└─────────────────────────────────────┘
```

### 10. **service_request_status_log** (Status History)
```
┌─────────────────────────────────────┐
│   SERVICE_REQUEST_STATUS_LOG        │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  service_request_id              │
│ FK  changed_by → user_profiles(id)  │
│     status (TEXT)                   │
│     changed_at (TIMESTAMPTZ)        │
│     notes (TEXT)                    │
└─────────────────────────────────────┘
```

### 11. **request_broadcasts** (Broadcast System)
```
┌─────────────────────────────────────┐
│       REQUEST_BROADCASTS            │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  service_request_id              │
│ FK  accepted_by → mechanics(id)     │
│     broadcast_radius (INTEGER)      │
│     mechanics_notified (INTEGER)    │
│     mechanics_responded (INTEGER)   │
│     status (TEXT)                   │
│     expires_at (TIMESTAMPTZ)        │
└─────────────────────────────────────┘
```

### 12. **earnings** (Mechanic Earnings)
```
┌─────────────────────────────────────┐
│           EARNINGS                  │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  mechanic_id → mechanics(id)     │
│ FK  service_request_id              │
│ FK  invoice_id → invoices(id)       │
│     amount (DECIMAL)                │
│     status (TEXT)                   │
│     earning_date (TIMESTAMPTZ)      │
│     payout_date (TIMESTAMPTZ)       │
└─────────────────────────────────────┘
```

### 13. **cash_payment_verifications**
```
┌─────────────────────────────────────┐
│   CASH_PAYMENT_VERIFICATIONS        │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  payment_id → payments(id)       │
│ FK  uploaded_by → user_profiles(id) │
│     proof_image_url (TEXT)          │
│     verification_status (TEXT)      │
│     verified_by (UUID)              │
│     verified_at (TIMESTAMPTZ)       │
└─────────────────────────────────────┘
```

---

## 💬 COMMUNICATION TABLES

### 14. **messages** (In-App Messaging)
```
┌─────────────────────────────────────┐
│           MESSAGES                  │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  service_request_id              │
│ FK  sender_id → user_profiles(id)   │
│ FK  receiver_id → user_profiles(id) │
│     message_text (TEXT)             │
│     message_type (TEXT)             │
│     is_read (BOOLEAN)               │
│     read_at (TIMESTAMPTZ)           │
│     created_at (TIMESTAMPTZ)        │
└─────────────────────────────────────┘
```

### 15. **notifications** (Push Notifications)
```
┌─────────────────────────────────────┐
│         NOTIFICATIONS               │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  user_id → user_profiles(id)     │
│ FK  service_request_id              │
│     title (TEXT)                    │
│     message (TEXT)                  │
│     notification_type (TEXT)        │
│     is_read (BOOLEAN)               │
│     read_at (TIMESTAMPTZ)           │
│     created_at (TIMESTAMPTZ)        │
└─────────────────────────────────────┘
```

### 16. **notification_templates** (Template System)
```
┌─────────────────────────────────────┐
│     NOTIFICATION_TEMPLATES          │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│     template_name (TEXT) UNIQUE     │
│     title_template (TEXT)           │
│     message_template (TEXT)         │
│     notification_type (TEXT)        │
│     is_active (BOOLEAN)             │
└─────────────────────────────────────┘
```

---

## ⭐ REVIEW & TRACKING TABLES

### 17. **reviews** (Service Reviews)
```
┌─────────────────────────────────────┐
│           REVIEWS                   │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  service_request_id              │
│ FK  customer_id → user_profiles(id) │
│ FK  mechanic_id → mechanics(id)     │
│ FK  shop_id → shops(id)             │
│     rating (INTEGER) 1-5            │
│     review_text (TEXT)              │
│     service_quality (INTEGER)       │
│     professionalism (INTEGER)       │
│     timeliness (INTEGER)            │
│     value_for_money (INTEGER)       │
│     photos (TEXT[])                 │
│     is_verified (BOOLEAN)           │
│     created_at (TIMESTAMPTZ)        │
└─────────────────────────────────────┘
```

### 18. **progress_photos** (Service Progress)
```
┌─────────────────────────────────────┐
│        PROGRESS_PHOTOS              │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  service_request_id              │
│ FK  uploaded_by → user_profiles(id) │
│     photo_url (TEXT)                │
│     description (TEXT)              │
│     phase (TEXT)                    │
│     uploaded_at (TIMESTAMPTZ)       │
└─────────────────────────────────────┘
```

### 19. **service_phase_tracking**
```
┌─────────────────────────────────────┐
│     SERVICE_PHASE_TRACKING          │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  service_request_id              │
│     phase (TEXT)                    │
│     started_at (TIMESTAMPTZ)        │
│     completed_at (TIMESTAMPTZ)      │
│     notes (TEXT)                    │
└─────────────────────────────────────┘
```

---

## 📊 HISTORY TABLES

### 20. **mechanic_job_history**
```
┌─────────────────────────────────────┐
│     MECHANIC_JOB_HISTORY            │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  mechanic_id → mechanics(id)     │
│ FK  service_request_id              │
│     job_title (TEXT)                │
│     completed_at (TIMESTAMPTZ)      │
│     earnings (DECIMAL)              │
│     rating (INTEGER)                │
└─────────────────────────────────────┘
```

### 21. **customer_job_history**
```
┌─────────────────────────────────────┐
│     CUSTOMER_JOB_HISTORY            │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  customer_id → user_profiles(id) │
│ FK  service_request_id              │
│     service_type (TEXT)             │
│     completed_at (TIMESTAMPTZ)      │
│     total_paid (DECIMAL)            │
│     rating_given (INTEGER)          │
└─────────────────────────────────────┘
```

---

## 🔒 SECURITY & AUDIT TABLES

### 22. **audit_logs** (System Audit Trail)
```
┌─────────────────────────────────────┐
│          AUDIT_LOGS                 │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  user_id → user_profiles(id)     │
│     action (TEXT)                   │
│     table_name (TEXT)               │
│     record_id (UUID)                │
│     old_data (JSONB)                │
│     new_data (JSONB)                │
│     ip_address (TEXT)               │
│     user_agent (TEXT)               │
│     created_at (TIMESTAMPTZ)        │
└─────────────────────────────────────┘
```

### 23. **account_security_logs**
```
┌─────────────────────────────────────┐
│     ACCOUNT_SECURITY_LOGS           │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  user_id → user_profiles(id)     │
│     event_type (TEXT)               │
│     ip_address (TEXT)               │
│     user_agent (TEXT)               │
│     location (TEXT)                 │
│     success (BOOLEAN)               │
│     created_at (TIMESTAMPTZ)        │
└─────────────────────────────────────┘
```

### 24. **document_verifications**
```
┌─────────────────────────────────────┐
│     DOCUMENT_VERIFICATIONS          │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  user_id → user_profiles(id)     │
│     document_type (TEXT)            │
│     document_url (TEXT)             │
│     verification_status (TEXT)      │
│     verified_by (UUID)              │
│     rejection_reason (TEXT)         │
│     verified_at (TIMESTAMPTZ)       │
└─────────────────────────────────────┘
```

### 25. **business_permits**
```
┌─────────────────────────────────────┐
│       BUSINESS_PERMITS              │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  shop_id → shops(id)             │
│     permit_number (TEXT)            │
│     business_name (TEXT)            │
│     owner_name (TEXT)               │
│     business_address (TEXT)         │
│     permit_image_url (TEXT)         │
│     issue_date (DATE)               │
│     expiry_date (DATE)              │
│     verification_status (TEXT)      │
│     verified_by (UUID)              │
│     verified_at (TIMESTAMPTZ)       │
└─────────────────────────────────────┘
```

---

## ⚙️ ADMIN & SYSTEM TABLES

### 26. **admin_users**
```
┌─────────────────────────────────────┐
│         ADMIN_USERS                 │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  user_id → user_profiles(id)     │
│     admin_role (TEXT)               │
│     permissions (TEXT[])            │
│     is_active (BOOLEAN)             │
│     created_at (TIMESTAMPTZ)        │
└─────────────────────────────────────┘
```

### 27. **admin_activity_logs**
```
┌─────────────────────────────────────┐
│     ADMIN_ACTIVITY_LOGS             │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│ FK  admin_id → admin_users(id)      │
│     action (TEXT)                   │
│     target_table (TEXT)             │
│     target_id (UUID)                │
│     details (JSONB)                 │
│     created_at (TIMESTAMPTZ)        │
└─────────────────────────────────────┘
```

### 28. **system_settings**
```
┌─────────────────────────────────────┐
│       SYSTEM_SETTINGS               │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│     setting_key (TEXT) UNIQUE       │
│     setting_value (JSONB)           │
│     description (TEXT)              │
│     updated_at (TIMESTAMPTZ)        │
└─────────────────────────────────────┘
```

### 29. **platform_statistics**
```
┌─────────────────────────────────────┐
│     PLATFORM_STATISTICS             │
├─────────────────────────────────────┤
│ PK  id (UUID)                       │
│     stat_date (DATE) UNIQUE         │
│     total_users (INTEGER)           │
│     total_requests (INTEGER)        │
│     completed_requests (INTEGER)    │
│     total_revenue (DECIMAL)         │
│     active_mechanics (INTEGER)      │
│     active_shops (INTEGER)          │
└─────────────────────────────────────┘
```

---

## 🔑 KEY RELATIONSHIPS SUMMARY

```
user_profiles (1) ──────────── (*) shops
user_profiles (1) ──────────── (1) mechanics
user_profiles (1) ──────────── (*) vehicles
user_profiles (1) ──────────── (*) service_requests
user_profiles (1) ──────────── (*) notifications
user_profiles (1) ──────────── (*) messages

shops (1) ──────────────────── (*) mechanics
shops (*) ──────────────────── (*) mechanics [via shop_mechanics]
shops (1) ──────────────────── (*) shop_services
shops (1) ──────────────────── (*) service_requests
shops (1) ──────────────────── (*) reviews

mechanics (1) ──────────────── (*) service_requests
mechanics (1) ──────────────── (*) earnings

service_requests (1) ────────── (1) invoices
service_requests (1) ────────── (*) messages
service_requests (1) ────────── (*) progress_photos
service_requests (1) ────────── (*) status_logs
service_requests (1) ────────── (0-1) reviews

invoices (1) ───────────────── (*) payments
payments (1) ───────────────── (0-1) cash_payment_verifications
```

---

## 📈 DATABASE STATISTICS

- **Total Active Tables**: 46
- **Core Business Tables**: 8
- **Support Tables**: 15
- **Communication Tables**: 5
- **Admin & Security Tables**: 8
- **History & Tracking Tables**: 10

---

**Generated for:** RoadAid Auto Repair Assistance System  
**Date:** October 9, 2025  
**Version:** 1.0 (Complete Schema)
