# RoadAid ERD - Figma Design Guide

**Date:** October 10, 2025  
**Purpose:** Visual Entity Relationship Diagram for Figma  
**Total Tables:** 66

---

## 🎨 Figma Design Instructions

### **Canvas Setup:**
- **Canvas Size:** 4000 x 3000px (scalable)
- **Background:** #F8F9FA (light gray)
- **Grid:** 20px grid for alignment

### **Color Scheme:**
```
Core Entities:        #4A90E2 (Blue)
Service Management:   #7B68EE (Purple)
Financial Tables:     #50C878 (Emerald)
Job History:          #F4A460 (Sandy Brown)
Notifications:        #FF6B6B (Red)
Security Tables:      #2C3E50 (Dark Blue)
Admin/Audit:          #95A5A6 (Gray)
Supporting Tables:    #F39C12 (Orange)
```

### **Table Card Template:**
```
┌─────────────────────────────────┐
│ 🔵 TABLE_NAME                   │ ← Header (Bold, 16px)
├─────────────────────────────────┤
│ 🔑 id: uuid (PK)                │ ← Primary Key
│ 🔗 foreign_key: uuid (FK)       │ ← Foreign Key
│ 📝 field_name: type             │ ← Regular Field
│ ⭐ unique_field: type (UNIQUE)  │ ← Unique Field
└─────────────────────────────────┘

Card Dimensions: 280px width, auto height
Corner Radius: 8px
Shadow: 0px 2px 8px rgba(0,0,0,0.1)
```

### **Relationship Lines:**
```
One-to-One (1:1):     ─────●─────●─────  (dots on both ends)
One-to-Many (1:N):    ─────●─────<─────  (dot and crow's foot)
Many-to-One (N:1):    ─────>─────●─────  (crow's foot and dot)
Many-to-Many (N:M):   ─────>─────<─────  (crow's feet on both ends)

Line Weight: 2px
Line Color: #34495E (Dark Gray)
```

---

## 📊 Entity Groups & Layout

### **Group 1: Core Entities (Top Center)**
Position: X: 1600, Y: 100

```
           auth.users
               │ 1:1
               ▼
         user_profiles ←──────────────┐
          │   │   │                   │
          │   │   └─────┐             │
          │   │         │             │
    1:1   │   │ 1:N     │ 1:1         │ 1:1
          │   │         │             │
          ▼   ▼         ▼             ▼
      service_  vehicles         shops
      providers                  (talyer_owner)
```

**Tables:**
1. **auth.users** (Blue #4A90E2)
   - id: uuid (PK)
   - email: text (UNIQUE)
   - encrypted_password: text
   - created_at: timestamptz

2. **user_profiles** (Blue #4A90E2)
   - id: uuid (PK, FK → auth.users)
   - first_name: varchar
   - last_name: varchar
   - email: varchar (UNIQUE)
   - phone_number: varchar
   - user_type: varchar
   - profile_image_url: text
   - current_latitude: numeric
   - current_longitude: numeric
   - shop_id: uuid (FK → shops)
   - status: varchar

3. **service_providers** (Blue #4A90E2)
   - id: uuid (PK)
   - user_id: uuid (FK → user_profiles)
   - shop_id: uuid (FK → shops)
   - talyer_owner_id: uuid (FK → user_profiles)
   - company_name: varchar
   - rating: numeric
   - service_radius: numeric
   - is_verified: boolean
   - is_available: boolean
   - status: varchar

4. **vehicles** (Blue #4A90E2)
   - id: uuid (PK)
   - user_id: uuid (FK → user_profiles)
   - brand_name: varchar
   - model_name: varchar
   - year: integer
   - plate_number: varchar
   - vehicle_type: varchar
   - is_primary: boolean

5. **shops** (Blue #4A90E2)
   - id: uuid (PK)
   - owner_id: uuid (FK → user_profiles)
   - shop_name: varchar
   - shop_address: text
   - latitude: numeric
   - longitude: numeric
   - service_radius: numeric
   - rating: numeric
   - is_active: boolean

---

### **Group 2: Service Management (Left Side)**
Position: X: 100, Y: 800

```
service_categories
        │ N:1
        ▼
shop_services ←──── shops
        │
        │ N:1
        ▼
service_requests ←── vehicles
        │         ←── user_profiles (customer)
        │         ←── service_providers
        │
        └────────────┐
```

**Tables:**
6. **service_categories** (Purple #7B68EE)
   - id: uuid (PK)
   - name: varchar (UNIQUE)
   - description: text
   - base_price: numeric
   - estimated_duration: integer
   - category_type: text
   - is_active: boolean

7. **service_requests** (Purple #7B68EE)
   - id: uuid (PK)
   - customer_id: uuid (FK → user_profiles)
   - provider_id: uuid (FK → service_providers)
   - vehicle_id: uuid (FK → vehicles)
   - category_id: uuid (FK → service_categories)
   - shop_id: uuid (FK → shops)
   - assigned_mechanic_id: uuid (FK → user_profiles)
   - title: varchar
   - description: text
   - status: varchar
   - pickup_latitude: numeric
   - pickup_longitude: numeric
   - service_fee: numeric
   - estimated_price: numeric
   - final_price: numeric
   - payment_status: varchar
   - request_type: text
   - is_broadcast_request: boolean

8. **shop_services** (Purple #7B68EE)
   - id: uuid (PK)
   - shop_id: uuid (FK → shops)
   - category_id: uuid (FK → service_categories)
   - service_name: text
   - description: text
   - base_price: numeric
   - custom_price: numeric
   - is_active: boolean

---

### **Group 3: Financial Flow (Right Side)**
Position: X: 3000, Y: 800

```
service_requests
        │ 1:N
        ▼
    invoices
        │ 1:N
        ▼
    payments ──────┐
        │ 1:1      │ 1:1
        ▼          ▼
payment_releases   cash_payment_verifications
```

**Tables:**
9. **invoices** (Green #50C878)
   - id: uuid (PK)
   - request_id: uuid (FK → service_requests)
   - customer_id: uuid (FK → user_profiles)
   - mechanic_id: uuid (FK → user_profiles)
   - talyer_owner_id: uuid (FK → user_profiles)
   - invoice_number: text (UNIQUE)
   - subtotal: numeric
   - platform_fee: numeric
   - total_amount: numeric
   - talyer_net_amount: numeric
   - provider_net_amount: numeric
   - status: text
   - selected_payment_method: text
   - generated_at: timestamptz
   - paid_at: timestamptz

10. **payments** (Green #50C878)
    - id: uuid (PK)
    - request_id: uuid (FK → service_requests)
    - customer_id: uuid (FK → user_profiles)
    - provider_id: uuid (FK → service_providers)
    - invoice_id: uuid (FK → invoices)
    - amount: numeric
    - platform_fee: numeric
    - provider_amount: numeric
    - payment_method: varchar
    - transaction_id: varchar
    - status: varchar
    - payment_gateway: varchar

11. **payment_releases** (Green #50C878)
    - id: uuid (PK)
    - payment_id: uuid (FK → payments)
    - request_id: uuid (FK → service_requests)
    - provider_id: uuid (FK → service_providers)
    - admin_id: uuid (FK → auth.users)
    - total_amount: numeric
    - platform_fee: numeric
    - provider_amount: numeric
    - release_status: varchar
    - release_method: varchar
    - approved_at: timestamptz
    - released_at: timestamptz

12. **cash_payment_verifications** (Green #50C878)
    - id: uuid (PK)
    - invoice_id: uuid (FK → invoices)
    - payment_id: uuid (FK → payments)
    - request_id: uuid (FK → service_requests)
    - customer_id: uuid (FK → user_profiles)
    - mechanic_id: uuid (FK → user_profiles)
    - verified_by: uuid (FK → auth.users)
    - cash_amount: numeric
    - cash_photo_url: text
    - verification_status: text
    - verified_at: timestamptz

---

### **Group 4: Job History (Bottom Center)**
Position: X: 1600, Y: 2000

```
service_requests
        │
        ├─────────────────┐
        │ 1:1              │ 1:1
        ▼                  ▼
mechanic_job_history   customer_job_history
```

**Tables:**
13. **mechanic_job_history** (Sandy Brown #F4A460)
    - id: uuid (PK)
    - mechanic_id: uuid (FK → user_profiles)
    - service_request_id: uuid (FK → service_requests)
    - customer_id: uuid (FK → user_profiles)
    - shop_id: uuid (FK → shops)
    - job_title: text
    - job_status: text
    - completed_at: timestamptz
    - total_amount: numeric
    - mechanic_earnings: numeric
    - shop_earnings: numeric
    - platform_fee: numeric
    - rating: numeric
    - review_text: text

14. **customer_job_history** (Sandy Brown #F4A460)
    - id: uuid (PK)
    - customer_id: uuid (FK → user_profiles)
    - service_request_id: uuid (FK → service_requests)
    - mechanic_id: uuid (FK → user_profiles)
    - shop_id: uuid (FK → shops)
    - job_title: text
    - job_status: text
    - completed_at: timestamptz
    - total_amount: numeric
    - rating: numeric
    - review_text: text

---

### **Group 5: Communication (Left Bottom)**
Position: X: 100, Y: 1800

```
user_profiles ────┐
        │         │
        │ 1:N     │ 1:N
        ▼         ▼
notifications  messages ──── service_requests
                  │
                  │
shops ────────────┤
        │ 1:N     │
        ▼         │
shop_notifications│
```

**Tables:**
15. **notifications** (Red #FF6B6B)
    - id: uuid (PK)
    - user_id: uuid (FK → user_profiles)
    - title: text
    - body: text
    - type: text
    - data: jsonb
    - read: boolean
    - created_at: timestamptz

16. **messages** (Red #FF6B6B)
    - id: uuid (PK)
    - request_id: uuid (FK → service_requests)
    - sender_id: uuid (FK → user_profiles)
    - receiver_id: uuid (FK → user_profiles)
    - message: text
    - sent_at: timestamptz
    - is_read: boolean

17. **shop_notifications** (Red #FF6B6B)
    - id: uuid (PK)
    - shop_id: uuid (FK → shops)
    - shop_owner_id: uuid (FK → user_profiles)
    - related_request_id: uuid (FK → service_requests)
    - notification_type: text
    - title: text
    - message: text
    - is_read: boolean

---

### **Group 6: Broadcast & Routing (Center)**
Position: X: 1600, Y: 1400

```
service_requests
        │
        ├─────────────────┐
        │ 1:N              │ 1:N
        ▼                  ▼
request_broadcasts    request_routing
        │                  │
        ├──────────────────┤
        ▼                  ▼
service_providers    shops
```

**Tables:**
18. **request_broadcasts** (Purple #7B68EE)
    - id: uuid (PK)
    - request_id: uuid (FK → service_requests)
    - provider_id: uuid (FK → service_providers)
    - shop_id: uuid (FK → shops)
    - mechanic_id: uuid (FK → user_profiles)
    - provider_type: text
    - distance_km: numeric
    - notification_sent_at: timestamptz
    - viewed_at: timestamptz
    - response_status: text
    - responded_at: timestamptz

19. **request_routing** (Purple #7B68EE)
    - id: uuid (PK)
    - request_id: uuid (FK → service_requests)
    - eligible_mechanic_id: uuid (FK → user_profiles)
    - eligible_shop_id: uuid (FK → shops)
    - routing_type: text
    - is_notified: boolean
    - distance_km: numeric

---

### **Group 7: Reviews (Right Bottom)**
Position: X: 3000, Y: 1800

```
service_requests
        │
        │ 1:N
        ▼
    reviews ──── user_profiles (customer)
        │
        └──────── service_providers
```

**Tables:**
20. **reviews** (Orange #F39C12)
    - id: uuid (PK)
    - request_id: uuid (FK → service_requests)
    - customer_id: uuid (FK → user_profiles)
    - provider_id: uuid (FK → service_providers)
    - rating: integer
    - comment: text
    - response: text
    - is_verified: boolean

---

### **Group 8: Progress Tracking (Left Center)**
Position: X: 100, Y: 1200

```
service_requests
        │
        ├─────────────────┐
        │ 1:N              │ 1:1
        ▼                  ▼
progress_photos    service_phase_tracking
        │
        └──────── user_profiles (mechanic)
```

**Tables:**
21. **progress_photos** (Purple #7B68EE)
    - id: uuid (PK)
    - service_request_id: uuid (FK → service_requests)
    - mechanic_id: uuid (FK → user_profiles)
    - service_phase: text
    - image_url: text
    - description: text
    - timestamp: timestamptz

22. **service_phase_tracking** (Purple #7B68EE)
    - id: uuid (PK)
    - service_request_id: uuid (FK → service_requests)
    - mechanic_id: uuid (FK → user_profiles)
    - current_phase: text
    - phase_started_at: timestamptz
    - phase_history: jsonb

---

### **Group 9: Security (Top Right)**
Position: X: 3000, Y: 100

```
auth.users
        │
        ├─────────────────┬─────────────────┐
        │ 1:N             │ 1:N             │ 1:N
        ▼                 ▼                 ▼
account_security_logs  password_reset_tokens  email_verification_tokens
```

**Tables:**
23. **account_security_logs** (Dark Blue #2C3E50)
    - id: uuid (PK)
    - user_id: uuid (FK → auth.users)
    - action_type: text
    - ip_address: inet
    - user_agent: text
    - success: boolean
    - created_at: timestamptz

24. **password_reset_tokens** (Dark Blue #2C3E50)
    - id: uuid (PK)
    - user_id: uuid (FK → auth.users)
    - token: text (UNIQUE)
    - expires_at: timestamptz
    - used_at: timestamptz
    - is_active: boolean

25. **email_verification_tokens** (Dark Blue #2C3E50)
    - id: uuid (PK)
    - user_id: uuid (FK → auth.users)
    - old_email: text
    - new_email: text
    - token: text (UNIQUE)
    - token_type: text
    - expires_at: timestamptz

---

### **Group 10: Mechanic Management (Top Left)**
Position: X: 100, Y: 100

```
user_profiles (talyer_owner)
        │
        │ 1:N
        ▼
mechanic_invitations ──── shops
        │
        └──────── auth.users (mechanic)

shops
        │
        │ 1:N
        ▼
shop_mechanics ──── user_profiles (mechanic)
        │
        └──────── mechanic_availability_status
```

**Tables:**
26. **mechanic_invitations** (Orange #F39C12)
    - id: uuid (PK)
    - shop_owner_id: uuid (FK → user_profiles)
    - shop_id: uuid (FK → shops)
    - mechanic_user_id: uuid (FK → auth.users)
    - email: text
    - first_name: text
    - last_name: text
    - temporary_password: text
    - invitation_token: text (UNIQUE)
    - status: text
    - expires_at: timestamptz

27. **shop_mechanics** (Orange #F39C12)
    - id: uuid (PK)
    - shop_id: uuid (FK → shops)
    - mechanic_id: uuid (FK → user_profiles)
    - role: varchar
    - hourly_rate: numeric
    - is_active: boolean
    - is_available: boolean

28. **mechanic_availability_status** (Orange #F39C12)
    - id: uuid (PK)
    - mechanic_id: uuid (FK → user_profiles)
    - shop_id: uuid (FK → shops)
    - current_request_id: uuid (FK → service_requests)
    - current_status: text
    - location_latitude: numeric
    - location_longitude: numeric
    - is_accepting_requests: boolean

---

### **Group 11: Verification (Bottom Right)**
Position: X: 3000, Y: 2200

```
auth.users
        │
        ├─────────────────┐
        │ 1:N             │ 1:N
        ▼                 ▼
document_verifications  business_permits ──── service_providers
                        
user_profiles (talyer_owner)
        │
        │ 1:1
        ▼
talyer_owner_verifications ──── auth.users (admin)
```

**Tables:**
29. **document_verifications** (Dark Blue #2C3E50)
    - id: uuid (PK)
    - user_id: uuid (FK → auth.users)
    - verified_by: uuid (FK → auth.users)
    - document_type: text
    - document_url: text
    - verification_status: text
    - verified_at: timestamptz

30. **business_permits** (Dark Blue #2C3E50)
    - id: uuid (PK)
    - provider_id: uuid (FK → service_providers)
    - verified_by: uuid (FK → auth.users)
    - business_permit_name: text
    - registered_address: text
    - receipt_no: text (UNIQUE)
    - permit_document_url: text
    - is_verified: boolean

31. **talyer_owner_verifications** (Dark Blue #2C3E50)
    - id: uuid (PK)
    - user_id: uuid (FK → user_profiles)
    - reviewed_by: uuid (FK → auth.users)
    - business_name: varchar
    - business_permit_url: text
    - valid_id_url: text
    - status: varchar
    - reviewed_at: timestamptz

---

### **Group 12: Job Completion (Center Bottom)**
Position: X: 1600, Y: 2400

```
service_requests
        │
        ├─────────────────┐
        │ N:1              │ N:1
        ▼                  ▼
job_completion_codes   service_completions
        │                  │
        ├──────────────────┤
        ▼                  ▼
service_providers    user_profiles (customer)
```

**Tables:**
32. **job_completion_codes** (Orange #F39C12)
    - id: uuid (PK)
    - request_id: uuid (FK → service_requests)
    - customer_id: uuid (FK → user_profiles)
    - used_by_provider_id: uuid (FK → service_providers)
    - completion_code: text (UNIQUE)
    - is_used: boolean
    - expires_at: timestamptz
    - used_at: timestamptz
    - verification_status: varchar

33. **service_completions** (Orange #F39C12)
    - id: uuid (PK)
    - request_id: uuid (FK → service_requests)
    - mechanic_id: uuid (FK → user_profiles)
    - customer_id: uuid (FK → user_profiles)
    - completion_code: text (UNIQUE)
    - qr_code_data: text
    - is_scanned: boolean
    - scanned_at: timestamptz
    - verification_status: text

---

### **Group 13: Admin & Audit (Bottom Left)**
Position: X: 100, Y: 2400

```
auth.users (admin)
        │
        │ 1:N
        ▼
admin_activity_logs

user_profiles
        │
        │ 1:N
        ▼
audit_logs
```

**Tables:**
34. **admin_activity_logs** (Gray #95A5A6)
    - id: uuid (PK)
    - admin_id: uuid (FK → auth.users)
    - action_type: varchar
    - target_type: varchar
    - target_id: uuid
    - action_details: jsonb
    - created_at: timestamptz

35. **audit_logs** (Gray #95A5A6)
    - id: uuid (PK)
    - user_id: uuid (FK → user_profiles)
    - role: varchar
    - action: text
    - table_name: varchar
    - record_id: uuid
    - old_values: jsonb
    - new_values: jsonb

---

### **Group 14: Email & Templates (Right Center)**
Position: X: 3000, Y: 1200

```
auth.users
        │
        │ 1:N
        ▼
email_notifications

notification_templates (standalone)
```

**Tables:**
36. **email_notifications** (Red #FF6B6B)
    - id: uuid (PK)
    - recipient_user_id: uuid (FK → auth.users)
    - sender_user_id: uuid (FK → auth.users)
    - email_type: text
    - recipient_email: text
    - subject: text
    - body: text
    - delivery_status: text

37. **notification_templates** (Red #FF6B6B)
    - id: uuid (PK)
    - category: text
    - priority: text
    - title_template: text
    - message_template: text
    - is_active: boolean

---

### **Group 15: Configuration (Top Center Right)**
Position: X: 2400, Y: 100

```
app_settings (standalone)

distance_pricing_config (standalone)
```

**Tables:**
38. **app_settings** (Gray #95A5A6)
    - id: uuid (PK)
    - key: varchar (UNIQUE)
    - value: text
    - description: text
    - is_public: boolean
    - category: text

39. **distance_pricing_config** (Gray #95A5A6)
    - id: uuid (PK)
    - base_rate_per_km: numeric
    - minimum_service_fee: numeric
    - maximum_service_fee: numeric
    - emergency_multiplier: numeric
    - is_active: boolean

---

## 🔗 Complete Relationship Matrix

### **Primary Relationships:**

| From Table | To Table | Type | Line Style | Color |
|------------|----------|------|------------|-------|
| auth.users | user_profiles | 1:1 | ─────●─────●───── | #4A90E2 |
| user_profiles | service_providers | 1:1 | ─────●─────●───── | #4A90E2 |
| user_profiles | shops | 1:1 | ─────●─────●───── | #4A90E2 |
| user_profiles | vehicles | 1:N | ─────●─────<───── | #4A90E2 |
| shops | service_providers | 1:N | ─────●─────<───── | #7B68EE |
| shops | shop_services | 1:N | ─────●─────<───── | #7B68EE |
| service_requests | invoices | 1:N | ─────●─────<───── | #50C878 |
| invoices | payments | 1:N | ─────●─────<───── | #50C878 |
| payments | payment_releases | 1:1 | ─────●─────●───── | #50C878 |
| service_requests | mechanic_job_history | 1:1 | ─────●─────●───── | #F4A460 |
| service_requests | customer_job_history | 1:1 | ─────●─────●───── | #F4A460 |
| user_profiles | notifications | 1:N | ─────●─────<───── | #FF6B6B |
| service_requests | messages | 1:N | ─────●─────<───── | #FF6B6B |
| service_requests | request_broadcasts | 1:N | ─────●─────<───── | #7B68EE |
| service_requests | reviews | 1:N | ─────●─────<───── | #F39C12 |
| service_requests | progress_photos | 1:N | ─────●─────<───── | #7B68EE |

---

## 📋 Implementation Checklist

### **Step 1: Setup Figma File**
- [ ] Create new Figma file: "RoadAid ERD"
- [ ] Set canvas to 4000x3000px
- [ ] Apply light gray background (#F8F9FA)
- [ ] Enable 20px grid

### **Step 2: Create Component Library**
- [ ] Create table card master component
- [ ] Create PK, FK, UNIQUE, regular field components
- [ ] Create relationship line styles (1:1, 1:N, N:1, N:M)
- [ ] Create color palette swatches

### **Step 3: Build Entity Groups**
- [ ] Group 1: Core Entities (5 tables)
- [ ] Group 2: Service Management (8 tables)
- [ ] Group 3: Financial Flow (4 tables)
- [ ] Group 4: Job History (2 tables)
- [ ] Group 5: Communication (3 tables)
- [ ] Group 6: Broadcast & Routing (2 tables)
- [ ] Group 7: Reviews (1 table)
- [ ] Group 8: Progress Tracking (2 tables)
- [ ] Group 9: Security (3 tables)
- [ ] Group 10: Mechanic Management (3 tables)
- [ ] Group 11: Verification (3 tables)
- [ ] Group 12: Job Completion (2 tables)
- [ ] Group 13: Admin & Audit (2 tables)
- [ ] Group 14: Email & Templates (2 tables)
- [ ] Group 15: Configuration (2 tables)

### **Step 4: Draw Relationships**
- [ ] Connect auth.users to user_profiles (1:1)
- [ ] Connect user_profiles to shops (1:1)
- [ ] Connect user_profiles to service_providers (1:1)
- [ ] Connect service_requests to all related tables
- [ ] Connect invoices to payments to payment_releases
- [ ] Connect all foreign key relationships
- [ ] Add relationship labels

### **Step 5: Add Annotations**
- [ ] Add group labels for each section
- [ ] Add legend for symbols and colors
- [ ] Add database statistics box
- [ ] Add timestamp and version info

### **Step 6: Export**
- [ ] Export as PNG (4000x3000px, 300 DPI)
- [ ] Export as PDF (A0 size for printing)
- [ ] Export as SVG (vector format)

---

## 🎯 Legend Template

```
┌─────────────────────────────────────────────────┐
│                    LEGEND                       │
├─────────────────────────────────────────────────┤
│                                                 │
│ SYMBOLS:                                        │
│ 🔑 PK = Primary Key                            │
│ 🔗 FK = Foreign Key                            │
│ ⭐ UNIQUE = Unique Constraint                  │
│ 📝 = Regular Field                             │
│                                                 │
│ RELATIONSHIPS:                                  │
│ ─────●─────●───── = One-to-One (1:1)          │
│ ─────●─────<───── = One-to-Many (1:N)         │
│ ─────>─────●───── = Many-to-One (N:1)         │
│ ─────>─────<───── = Many-to-Many (N:M)        │
│                                                 │
│ COLORS:                                         │
│ 🔵 Blue      - Core Entities                   │
│ 🟣 Purple    - Service Management              │
│ 🟢 Green     - Financial Tables                │
│ 🟠 Orange    - Supporting Tables               │
│ 🔴 Red       - Notifications                   │
│ ⚫ Dark Blue - Security                        │
│ ⚪ Gray      - Admin/Config                    │
│                                                 │
│ DATABASE STATS:                                 │
│ • Total Tables: 66                             │
│ • Total Relationships: 120+                    │
│ • Normalization: 3NF                           │
│ • Database: PostgreSQL (Supabase)             │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## 📤 Export Specifications

### **For Thesis/Documentation:**
- **Format:** PDF
- **Size:** A1 (594 x 841 mm) or A0 (841 x 1189 mm)
- **Resolution:** 300 DPI
- **Color Mode:** CMYK for printing, RGB for digital

### **For Presentation:**
- **Format:** PNG
- **Size:** 1920 x 1080 px (16:9 aspect ratio)
- **Resolution:** 72 DPI
- **Background:** White or transparent

### **For Web:**
- **Format:** SVG
- **Optimization:** Compressed
- **Viewbox:** Responsive

---

**Created:** October 10, 2025  
**Version:** 1.0  
**Status:** Ready for Figma Implementation  
**Total Entities:** 66 Tables  
**Total Relationships:** 120+ Connections
